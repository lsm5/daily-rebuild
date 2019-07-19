#!/bin/sh

. env.sh

# update spec changelog and release value
bump_spec ()
{
    pushd $PKG_DIR/$PACKAGE
    export CURRENT_VERSION=$(cat $PACKAGE.spec | grep -m 1 "Version:" | sed -e "s/Version: //")
    if [ $CURRENT_VERSION == $VERSION ]; then
       echo "No new upstream release. Exiting..."
       exit 0
    else
       sudo dnf update --nogpgcheck -y
       sed -i "0,/\%global commit0.*/{s/\%global commit0.*/\%global commit0 $COMMIT/}" $PACKAGE.spec
       if [ $PACKAGE == container-selinux ]; then
          sed -i "0,/\%global commit0.*/! {0,/\%global commit0.*/ s/\%global commit0.*/\%global commit0 $COMMIT_CENTOS/}" $PACKAGE.spec
       fi
       sed -i "s/Version: [0-9.]*/Version: $VERSION/" $PACKAGE.spec
       sed -i "s/Release: [0-9]*/Release: 0/" $PACKAGE.spec
       echo "- bump to $VERSION" > /tmp/$PACKAGE.changelog
       if [ $PACKAGE == container-selinux ]; then
          echo "- autobuilt $SHORTCOMMIT for fedora" >> /tmp/$PACKAGE.changelog
          echo "- autobuilt $SHORTCOMMIT_CENTOS for centos" >> /tmp/$PACKAGE.changelog
       else
          echo "- autobuilt $SHORTCOMMIT" >> /tmp/$PACKAGE.changelog
       fi
       rpmdev-bumpspec -c "$(cat /tmp/$PACKAGE.changelog)" $PACKAGE.spec
    fi
    popd
}

# rpmbuild
fetch_pkg_and_build ()
{
   cd $PKG_DIR
   if [ ! -d $PACKAGE ]; then
      $DIST_PKG clone $PACKAGE
   fi
   pushd $PKG_DIR/$PACKAGE
   git checkout $DIST_GIT_TAG
   bump_spec
   spectool -g $PACKAGE.spec
   sudo $BUILDDEP $PACKAGE.spec -y
   rpmbuild -ba $PACKAGE.spec
   if [ $? -ne 0 ]; then
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
    if [ $? -ne 0 ]; then
        echo "git push FAIL!!!"
        exit 1
    fi
    $DIST_PKG build
    echo $FEDORA_KRB_PASSWORD | $DIST_PKG update --type=bugfix --notes "Autobuilt v$VERSION"
    rm -rf SRPMS/*
    # build for CentOS Virt SIG
    rpmbuild -ba --define='dist .el7' $PACKAGE.spec
    # remove epoch from NVR for centos builds
    export CENTOS_NVR=$(echo $NVR | sed -e 's/[^:]*://')
    cbs build virt7-container-common-el7 SRPMS/$PACKAGE-$CENTOS_NVR.el7.src.rpm
    if [ $? -ne 0 ]; then
       cbs tag-pkg virt7-container-common-testing $PACKAGE-$CENTOS_NVR.el7
    fi
    popd
}
