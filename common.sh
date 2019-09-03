#!/bin/sh

. $(pwd)/env.sh

try_bodhi_updates ()
{
    if [[ $BUILDTYPE == "tagged" ]]; then
       pushd $PKG_DIR/$PACKAGE
       echo "Fetching NVRs for bodhi builds..."
       export CURRENT_STABLE_BUILD=$(koji latest-pkg --quiet $DIST_GIT_TAG-updates $PACKAGE | awk '{print $1}')
       export CURRENT_TESTING_BUILD=$(koji latest-pkg --quiet $DIST_GIT_TAG-updates-testing $PACKAGE | awk '{print $1}')
       if [ $CURRENT_STABLE_BUILD != $CURRENT_TESTING_BUILD ]; then
          echo "Try submitting testing build to stable if any..."
          echo "Getting Bodhi ID..."
          export BODHI_ID=$(bodhi updates query --packages $PACKAGE --releases $DIST_GIT_TAG --status testing | grep 'Update ID' | sed -e 's/   Update ID: //')
          echo "Checking if bodhi update is of type Security..."
          bodhi updates query --updateid $BODHI_ID | grep 'Type: security'
          if [[ $? == 0 ]]; then
             export BODHI_UPDATE_TYPE="security"
             echo "YUP, SECURITY UPDATE!!!"
          else
             echo "Nope, not a security update"
          fi
          bodhi updates request --user lsm5 --password $FEDORA_KRB_PASSWORD $BODHI_ID stable
          if [[ $? -ne 0 ]]; then
             if [[ $BODHI_UPDATE_TYPE == "security" ]]; then
                echo "Current bodhi update in testing is of type Security. Refusing to obsolete with new build..."
                exit 1
             else
                echo "Build in updates-testing not qualified for stable push but isn't of type Security. Moving on..."
             fi
          else
             if [[ $CHECK_CENTOS == "true" ]]; then
                echo "Pushing CentOS build to -release branch since Fedora build qualified..."
                export CURRENT_CENTOS_TESTING_BUILD=$(echo $CURRENT_TESTING_BUILD | sed -e "s/$KOJI_BUILD_SUFFIX/\.el7/")
                cbs tag-pkg paas7-crio-11x-release $CURRENT_CENTOS_TESTING_BUILD
             fi
          fi
       fi
       popd
    fi
}

# update spec changelog and release value
bump_spec ()
{
   #try_bodhi_updates
   pushd $PKG_DIR/$PACKAGE
   export CURRENT_VERSION=$(cat $PACKAGE.spec | grep -m 1 "Version:" | sed -e "s/Version: //")
   export CURRENT_TAG=$(grep 'global built_tag' $PACKAGE.spec | sed -e 's/.*tag //')
   #VERSION_COMP=$(awk -vx=$CURRENT_VERSION -vy=$LATEST_VERSION 'BEGIN{ print x>=y?1:0 }')
   #if [[ $VERSION_COMP -eq 1 ]]; then
   #   echo "Packaged version isn't released yet. Exiting..."
   #   exit 0
   #fi
   if [[ $CURRENT_TAG == $LATEST_TAG ]]; then
      echo "No new upstream tag. Exiting..."
      exit 0
   else
      echo "Updating container..."
      sudo dnf update --nogpgcheck -y
      echo "Deleting previous tmp changelog files if any..."
      if [[ -f /tmp/$PACKAGE.changelog ]]; then
         rm -f /tmp/$PACKAGE.changelog
      fi
      echo "Recording upstream commit and tag to spec..."
      sed -i "0,/\%global built_tag.*/{s/%global built_tag.*/\%global built_tag $LATEST_TAG/}" $PACKAGE.spec
      sed -i "0,/\%global commit0.*/{s/\%global commit0.*/\%global commit0 $COMMIT/}" $PACKAGE.spec
      if [[ $CURRENT_VERSION != $LATEST_VERSION ]]; then
         echo "- bump to $LATEST_TAG" >> /tmp/$PACKAGE.changelog
         echo "- autobuilt $SHORTCOMMIT" >> /tmp/$PACKAGE.changelog
         sed -i "s/Version: [0-9.]*/Version: $LATEST_VERSION/" $PACKAGE.spec
         sed -i "s/Release: [0-9]*/Release: 1/" $PACKAGE.spec
      fi
      rpmdev-bumpspec -c "$(cat /tmp/$PACKAGE.changelog)" $PACKAGE.spec
   fi
   popd
}

# rpmbuild
fetch_pkg_and_build ()
{
   cd $PKG_DIR
   if [[ ! -d $PACKAGE ]]; then
      $DIST_PKG clone $PACKAGE
   fi
   cd $PKG_DIR/$PACKAGE
   git checkout $DIST_GIT_TAG
   bump_spec
   spectool -g $PACKAGE.spec
   sudo $BUILDDEP -y $PACKAGE.spec
   rpmbuild -br --quiet $PACKAGE.spec
   if [[ $? -ne 0 ]]; then
       echo "rpm build FAIL!!!"
       exit 1
   fi
}

# update dist-git
commit_to_dist_git ()
{
   pushd $PKG_DIR/$PACKAGE
   $DIST_PKG new-sources *.tar*
   export NVR=$(grep -A 1 '%changelog' $PACKAGE.spec | sed '$!d' | sed -e "s/[^']* - //")
   git commit -as -m "$PACKAGE-$NVR" -m "$(cat /tmp/$PACKAGE.changelog)"
   popd
}

# push and build
push_and_build ()
{
   pushd $PKG_DIR/$PACKAGE
   git push -u origin $DIST_GIT_TAG
   if [[ $? -ne 0 ]]; then
       echo "git push FAIL!!!"
       exit 1
   fi
   rm -rf SRPMS/*
   # build for CentOS PaaS SIG
   rpmbuild -br --quiet --define='dist .el7' $PACKAGE.spec
   # remove epoch from NVR for CentOS builds
   export CENTOS_NVR=$(echo $NVR | sed -e 's/[^:]*://')
   cbs build --wait paas7-crio-$CENTOS_SIG_TAG-el7 SRPMS/$PACKAGE-$CENTOS_NVR.el7.src.rpm
   if [[ $? -ne 0 ]]; then
      cbs tag-pkg paas7-crio-$CENTOS_SIG_TAG-testing $PACKAGE-$CENTOS_NVR.el7
   fi
   popd
   # build fedora module
   #cd $MODULE_DIR
   #if [ ! -d $MODULE ]; then
   #   $DIST_PKG clone modules/$MODULE
   #fi
   #cd $MODULE_DIR/$MODULE
   #git checkout $DIST_GIT_TAG
   #git commit --allow-empty -asm 'autobuilt v$VERSION'
   #git push -u origin $DIST_GIT_TAG
   #$DIST_PKG module-build
   #bodhi updates new --user $FEDORA_USER --password $FEDORA_KRB_PASSWORD $MODULE_BUILD_ID --type=bugfix --notes "Autobuilt v$VERSION" $MODULE_BUILD_ID
}
