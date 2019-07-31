#!/bin/sh

. env.sh

# check if packages can be pushed to stable
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
               cbs tag-pkg virt7-container-common-release $CURRENT_CENTOS_TESTING_BUILD
            fi
         fi
      fi
      popd
   fi
}

# update spec changelog and release value
bump_spec ()
{
   try_bodhi_updates
   pushd $PKG_DIR/$PACKAGE
   export CURRENT_VERSION=$(cat $PACKAGE.spec | grep -m 1 "Version:" | sed -e "s/Version: //")
   export CURRENT_TAG=$(grep 'global built_tag' $PACKAGE.spec | sed -e 's/.*tag //')
   if [[ $CURRENT_TAG == $LATEST_TAG && $PACKAGE != "container-selinux" ]]; then
      echo "No new upstream tag. Exiting..."
      exit 0
   else
      if [[ $CURRENT_VERSION == $VERSION ]]; then
         if [[ $PACKAGE == "container-selinux" ]]; then
            echo "No new upstream version. Exiting..."
            exit 0
         else
            echo "No change in spec's Version field..."
         fi
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
         if [[ $PACKAGE == "container-selinux" ]]; then
            sed -i "0,/\%global commit_centos.*/{s/\%global commit_centos.*/\%global commit_centos $COMMIT_CENTOS/}" $PACKAGE.spec
            sed -i "0,/\%global commit0.*/! {0,/\%global commit0.*/ s/\%global commit0.*/\%global commit0 $COMMIT_CENTOS/}" $PACKAGE.spec
            echo "- autobuilt $SHORTCOMMIT for fedora" >> /tmp/$PACKAGE.changelog
            echo "- autobuilt $SHORTCOMMIT_CENTOS for centos" >> /tmp/$PACKAGE.changelog
         fi
         sed -i "s/Version: [0-9.]*/Version: $VERSION/" $PACKAGE.spec
         sed -i "s/Release: [0-9]*/Release: 1/" $PACKAGE.spec
         echo "- bump to $VERSION" > /tmp/$PACKAGE.changelog
      fi
      echo "- autobuilt $SHORTCOMMIT" >> /tmp/$PACKAGE.changelog
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
   pushd $PKG_DIR/$PACKAGE
   git checkout $DIST_GIT_TAG
   bump_spec
   spectool -g $PACKAGE.spec
   sudo $BUILDDEP $PACKAGE.spec -y
   rpmbuild -br --quiet $PACKAGE.spec
   if [[ $? -ne 0 ]]; then
       echo "rpm build FAIL!!!"
       exit 1
   fi
   popd
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
    git status
    if [[ $? -ne 0 ]]; then
        echo "git push FAIL!!!"
        exit 1
    fi
    $DIST_PKG build
    echo $FEDORA_KRB_PASSWORD | $DIST_PKG update --type=bugfix --notes "Autobuilt v$VERSION"
    rm -rf SRPMS/*
    if [[ $CHECK_CENTOS == "true" ]]; then
       echo "Building for CentOS Virt SIG..."
      rpmbuild -br --quiet --define='dist .el7' $PACKAGE.spec
      echo "Removing epoch from NVR for centos builds..."
      export CENTOS_NVR=$(echo $NVR | sed -e 's/[^:]*://')
      cbs build --wait virt7-container-common-el7 SRPMS/$PACKAGE-$CENTOS_NVR.el7.src.rpm
      if [[ $? -ne 0 ]]; then
         cbs tag-pkg virt7-container-common-testing $PACKAGE-$CENTOS_NVR.el7
      fi
    fi
    popd
}
