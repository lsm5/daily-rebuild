#!/bin/sh

export NAME="RH Container Bot"
export EMAIL="rh.container.bot@gmail.com"
export USER="rh-container-bot"
export DEBFULLNAME=$NAME
export DEBEMAIL=$EMAIL

export DISTRO="ubuntu"

if [[ $DISTRO_VERSION == "xenial" ]]; then
   export DISTRO_VERSION_ID="16.04"
elif [[ $DISTRO_VERSION == "bionic" ]]; then
   export DISTRO_VERSION_ID="18.04"
elif [[ $DISTRO_VERSION == "disco" ]]; then
   export DISTRO_VERSION_ID="19.04"
fi

cd ~/.ssh
#openssl enc -aes-256-cbc -pbkdf2 -d -in id_rsa.enc -out id_rsa -pass pass:$DECRYPTION_PASSPHRASE
#chmod 600 id_rsa
openssl enc -aes-256-cbc -pbkdf2 -d -in rh-container-bot_rsa.enc -out rh-container-bot_rsa -pass pass:$DECRYPTION_PASSPHRASE
echo "Set correct permissions for SSH priv key..."
chmod 600 rh-container-bot_rsa

echo "Importing GPG priv key..."
cd ~
#openssl enc -aes-256-cbc -pbkdf2 -d -in lsm5-bot-privkey.enc -out lsm5-bot-privkey.asc -pass pass:$DECRYPTION_PASSPHRASE
#echo $GPG_KEY_PASSPHRASE | gpg --passphrase-fd 0 --allow-secret-key-import --import $(pwd)/lsm5-bot-privkey.asc
openssl enc -aes-256-cbc -pbkdf2 -d -in rh-container-bot-privkey.enc -out rh-container-bot-privkey.asc -pass pass:$DECRYPTION_PASSPHRASE
echo $RH_BOT_GPG_KEY_PASSPHRASE | gpg --passphrase-fd 0 --allow-secret-key-import --import $(pwd)/rh-container-bot-privkey.asc

cd ~/repositories/$PACKAGE
echo "Fetching git remotes..."
git fetch --all

if [[ $PACKAGE == "cri-o" ]]; then
   echo "Getting info for latest release-$BRANCH for $PACKAGE..."
   git checkout origin/release-$BRANCH
   export LATEST_COMMIT=$(git show --pretty=%H -s origin/release-$BRANCH)
   export LATEST_SHORTCOMMIT=$(c=$LATEST_COMMIT; echo ${c:0:7})
   export LATEST_VERSION=$(grep 'const Version' version/version.go | sed -e 's/const Version = "//' -e 's/-.*//')
   echo "Checking out branch with debian changes..."
   git checkout gitlab/$DISTRO_VERSION-$BRANCH -b $DISTRO_VERSION-$BRANCH
   echo "Extracting current commit from deb package..."
   export CURRENT_COMMIT=$(grep UPSTREAM_COMMIT debian/rules | sed -e 's/UPSTREAM_COMMIT=//')
   export CURRENT_VERSION=$(dpkg-parsechangelog --show-field Version | sed -e 's/-.*//')
   if [[ $CURRENT_COMMIT == $LATEST_COMMIT && $FORCE_REBUILD != "true" ]]; then
      echo "No new upstream commits. Exiting..."
      exit 0
   else
      echo "Rebasing $DISTRO_VERSION-$BRANCH on top of commit $LATEST_SHORTCOMMIT for $PACKAGE..."
      git rebase $LATEST_COMMIT
      if [[ $? -ne 0 ]]; then
         echo "Rebase on commit $LATEST_SHORTCOMMIT failed. Exiting..."
         exit 1
      else
         sed -i "s/UPSTREAM_COMMIT=.*/UPSTREAM_COMMIT=$LATEST_COMMIT/" debian/rules
         echo "Bumping changelog..."
         if [[ $LATEST_VERSION != $CURRENT_VERSION ]]; then
            debchange --package "$PACKAGE-$BRANCH" -v "$LATEST_VERSION-1~dev~$DISTRO$DISTRO_VERSION_ID~ppa1" -D $DISTRO_VERSION "bump to v$LATEST_VERSION, autobuilt $LATEST_SHORTCOMMIT"
            git commit -asm "bump to $LATEST_VERSION, autobuilt $LATEST_SHORTCOMMIT"
         else
            debchange --package "$PACKAGE-$BRANCH" -i -D $DISTRO_VERSION "autobuilt $LATEST_SHORTCOMMIT"
            git commit -asm "autobuilt $LATEST_SHORTCOMMIT"
         fi
      fi
   fi
else
   echo "Getting info for latest tag for $PACKAGE..."
   export LATEST_TAG=$(git describe --tags --abbrev=0 origin/master)
   export LATEST_VERSION=$(echo $LATEST_TAG | sed -e 's/v//' -e 's/-.*//')
   echo "Checking out branch with debian changes..."
   git checkout gitlab/$DISTRO_VERSION -b $DISTRO_VERSION
   export DEB_PKG_TAG=$(grep UPSTREAM_TAG debian/rules | sed -e 's/UPSTREAM_TAG=//')
   export CURRENT_VERSION=$(dpkg-parsechangelog --show-field Version | sed -e 's/-.*//')
   if [[ $DEB_PKG_TAG == $LATEST_TAG && $FORCE_REBUILD != "true" ]]; then
      echo "No new upstream release. Exiting..."
      exit 0
   else
      echo "Rebasing $DISTRO_VERSION on top of tag $LATEST_TAG for $PACKAGE..."
      git rebase $LATEST_TAG
      if [[ $? -ne 0 ]]; then
         echo "Rebase on tag $LATEST_TAG failed. Exiting..."
         exit 1
      fi
      echo "Bumping changelog..."
      if [[ $CURRENT_VERSION == $LATEST_VERSION ]]; then
         debchange --package "$PACKAGE" -i -D $DISTRO_VERSION "autobuilt $LATEST_TAG"
      else
         debchange --package "$PACKAGE" -v "$LATEST_VERSION-1~$DISTRO$DISTRO_VERSION_ID~ppa1" -D $DISTRO_VERSION "bump to $LATEST_TAG"
      fi
      sed -i "s/UPSTREAM_TAG=.*/UPSTREAM_TAG=$LATEST_TAG/" debian/rules
      git commit -asm "bump to $LATEST_TAG"
   fi
fi

echo "Updating image and deps..."
sudo apt -qq update
sudo apt -qqy dist-upgrade

#echo "Installing dependencies..."
#sudo mk-build-deps -i

echo "Building package..."
debuild -i -us -uc -S -sa

echo "Signing deb package..."
echo "Y" | debsign -e"$DEBFULLNAME <$DEBEMAIL>" -p"gpg --yes -q --passphrase $RH_BOT_GPG_KEY_PASSPHRASE --batch"\
        ../*.dsc
if [ $? -ne 0 ]; then
        echo "Failed to sign dsc file. Exiting..."
        exit 1
fi

echo "Y" | debsign -e"$DEBFULLNAME <$DEBEMAIL>" -p"gpg --yes -q --passphrase $RH_BOT_GPG_KEY_PASSPHRASE --batch"\
        ../*_source.changes
if [ $? -ne 0 ]; then
        echo "Failed to sign changes file. Exiting..."
        exit 1
fi

echo "Pushing changes to gitlab/$PACKAGE..."
if [[ $PACKAGE == "cri-o" ]]; then
        GIT_SSH_COMMAND="ssh -i $HOME/.ssh/rh-container-bot_rsa" git push -u gitlab $DISTRO_VERSION-$BRANCH -f
else
        GIT_SSH_COMMAND="ssh -i $HOME/.ssh/rh-container-bot_rsa" git push -u gitlab $DISTRO_VERSION -f
fi
if [ $? -ne 0 ]; then
        echo "Failed to push changes to gitlab. Exiting..."
        exit 1
fi

echo "Adding github mirror..."
git remote add github github:lsm5/$PACKAGE.git
echo "Pushing changes to github/$PACKAGE..."
if [[ $PACKAGE == "cri-o" ]]; then
        GIT_SSH_COMMAND="ssh -i $HOME/.ssh/rh-container-bot_rsa" git push -u github $DISTRO_VERSION-$BRANCH -f
else
        GIT_SSH_COMMAND="ssh -i $HOME/.ssh/rh-container-bot_rsa" git push -u github $DISTRO_VERSION -f
fi
if [ $? -ne 0 ]; then
        echo "Failed to push changes to github, not critical. Continuing..."
fi

echo "Submitting build to PPA..."
dput ppa:projectatomic/ppa ../*_source.changes
if [ $? -ne 0 ]; then
        echo "Failed to send build to PPA. Exiting..."
        exit 1
fi
echo "Done!!!"

