#!/bin/sh

# Get ubuntu version variables
. /etc/os-release

export NAME="Lokesh Mandvekar (Bot)"
export EMAIL="lsm5+bot@fedoraproject.org"
export USER="lsm5+bot"
export DEBFULLNAME=$NAME
export DEBEMAIL=$EMAIL

cd ~/.ssh
openssl enc -aes-256-cbc -pbkdf2 -d -in id_rsa.enc -out id_rsa -pass pass:$DECRYPTION_PASSPHRASE
echo "Set correct permissions for SSH priv key..."
chmod 600 ~/.ssh/id_rsa

echo "Importing GPG priv key..."
cd ~
openssl enc -aes-256-cbc -pbkdf2 -d -in lsm5-bot-privkey.enc -out lsm5-bot-privkey.asc -pass pass:$DECRYPTION_PASSPHRASE
echo $GPG_KEY_PASSPHRASE | gpg --passphrase-fd 0 --allow-secret-key-import --import $(pwd)/lsm5-bot-privkey.asc

cd ~/repositories/$PACKAGE
echo "Adding and fetching git upstream remote..."
git fetch --all
if [[ $PACKAGE == "cri-o" ]]; then
        # build latest release-* branch for cri-o
        git checkout origin/release-$BRANCH
        export LATEST_COMMIT=$(git show --pretty=%H -s origin/release-$BRANCH)
        export LATEST_SHORTCOMMIT=$(c=$LATEST_COMMIT; echo ${c:0:7})
        export LATEST_VERSION=$(grep 'const Version' version/version.go | sed -e 's/const Version = "//' -e 's/-.*//')
        # checkout branch with debian changes
        git checkout $VERSION_CODENAME-$BRANCH
else
        export LATEST_TAG=$(git describe --tags --abbrev=0 origin/master)
        export LATEST_COMMIT=$(git rev-parse $LATEST_TAG)
        export LATEST_SHORTCOMMIT=$(c=$LATEST_COMMIT; echo ${c:0:7})
        export LATEST_VERSION=$(echo $LATEST_TAG | sed -e 's/v//' -e 's/-.*//')
        # checkout branch with debian changes
        git checkout $VERSION_CODENAME 
fi

echo "Extracting current version/commit from deb package..."
if [[ $PACKAGE == "cri-o" ]]; then
   export CURRENT_COMMIT=$(dpkg-parsechangelog -c 1 | grep built | sed -e 's/.*built //')
else
   export CURRENT_VERSION=$(dpkg-parsechangelog --show-field Version | sed -e 's/-.*//')
fi

# Rebase build repo on top of latest tag
if [ $PACKAGE == "cri-o" ]; then
   git rebase $LATEST_COMMIT
   if [ $? -ne 0 ]; then
        echo "Rebase on commit $LATEST_COMMIT failed. Exiting..."
        exit 1
   fi
else
   git rebase $LATEST_TAG
   if [ $? -ne 0 ]; then
        echo "Rebase on tag $LATEST_TAG failed. Exiting..."
        exit 1
   fi
fi

echo "Bump changelog if new commits for cri-o or new version for others..."
if [[ $PACKAGE == "cri-o" ]]; then
   if [[ $LATEST_COMMIT == $CURRENT_COMMIT ]]; then
      echo "No new upstream commits. Exiting..."
   else
      echo "Bumping changelog..."
      if [[ $LATEST_VERSION != $CURRENT_VERSION ]]; then
         debchange --package "$PACKAGE-$BRANCH" -v "$LATEST_VERSION-1~dev~$ID$VERSION_ID~ppa1" -D $VERSION_CODENAME "bump to $LATEST_VERSION, autobuilt $LATEST_SHORTCOMMIT"
      else
         debchange --package "$PACKAGE-$BRANCH" -i -D $VERSION_CODENAME "autobuilt $LATEST_SHORTCOMMIT"
      fi
      git commit -asm "bump to $LATEST_VERSION"
   fi
else
   if [ $LATEST_VERSION == $CURRENT_VERSION ]; then
      echo "No new upstream release. Exiting..."
      exit 0
   else
      echo "Bumping changelog..."
      debchange --package "$PACKAGE" -v "$LATEST_VERSION-1~$ID$VERSION_ID~ppa1" -D $VERSION_CODENAME "bump to $LATEST_VERSION"
      git commit -asm "bump to $LATEST_VERSION"
   fi
fi

echo "Updating image and deps..."
sudo apt -qq update
sudo apt -qqy dist-upgrade

echo "Installing dependencies..."
sudo mk-build-deps -i

echo "Building package..."
debuild -i -us -uc -S -sa

echo "Signing deb package..."
echo "Y" | debsign -e"$DEBFULLNAME <$DEBEMAIL>" -p"gpg --yes -q --passphrase $GPG_KEY_PASSPHRASE --batch"\
        ../*.dsc
if [ $? -ne 0 ]; then
        echo "Failed to sign dsc file. Exiting..."
        exit 1
fi

echo "Y" | debsign -e"$DEBFULLNAME <$DEBEMAIL>" -p"gpg --yes -q --passphrase $GPG_KEY_PASSPHRASE --batch"\
        ../*_source.changes
if [ $? -ne 0 ]; then
        echo "Failed to sign changes file. Exiting..."
        exit 1
fi

echo "Pushing changes to gitlab/$PACKAGE..."
if [[ $PACKAGE == "cri-o" ]]; then
        GIT_SSH_COMMAND="ssh -i $HOME/.ssh/id_rsa" git push -u gitlab $VERSION_CODENAME-$BRANCH -f
else
        GIT_SSH_COMMAND="ssh -i $HOME/.ssh/id_rsa" git push -u gitlab $VERSION_CODENAME -f
fi
if [ $? -ne 0 ]; then
        echo "Failed to push changes to gitlab. Exiting..."
        exit 1
fi

echo "Adding github mirror..."
git remote add github github:lsm5/$PACKAGE.git
echo "Pushing changes to github/$PACKAGE..."
if [[ $PACKAGE == "cri-o" ]]; then
        GIT_SSH_COMMAND="ssh -i $HOME/.ssh/id_rsa" git push -u github $VERSION_CODENAME-$BRANCH -f
else
        GIT_SSH_COMMAND="ssh -i $HOME/.ssh/id_rsa" git push -u github $VERSION_CODENAME -f
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

