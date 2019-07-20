#!/bin/sh

. env.sh

# update spec changelog and release value
bump_spec ()
{
   export CURRENT_VERSION=$(cat $PACKAGE.spec | grep -m 1 "Version:" | sed -e "s/Version: //")
   if [ $CURRENT_VERSION == $VERSION ]; then
      echo "No new upstream release. Exiting..."
      exit 0
   else
      sudo dnf update --nogpgcheck -y
      sed -i "0,/\%global commit0.*/{s/\%global commit0.*/\%global commit0 $COMMIT/}" $PACKAGE.spec
      if [ $PACKAGE == container-selinux ]; then
         sed -i "0,/\%global commit_centos.*/{s/\%global commit_centos.*/\%global commit_centos $COMMIT_CENTOS/}" $PACKAGE.spec
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
}

# rpmbuild
fetch_pkg_and_build ()
{
   cd $PKG_DIR
   if [ ! -d $PACKAGE ]; then
      $DIST_PKG clone $PACKAGE
   fi
   cd $PKG_DIR/$PACKAGE
   git checkout $DIST_GIT_TAG
   bump_spec
   spectool -g $PACKAGE.spec
   sudo $BUILDDEP -y $PACKAGE.spec
   rpmbuild -br --quiet $PACKAGE.spec
   if [ $? -ne 0 ]; then
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
   if [ $? -ne 0 ]; then
       echo "git push FAIL!!!"
       exit 1
   fi
   rm -rf SRPMS/*
   # build for CentOS PaaS SIG
   rpmbuild -br --quiet --define='dist .el7' $PACKAGE.spec
   # remove epoch from NVR for CentOS builds
   export CENTOS_NVR=$(echo $NVR | sed -e 's/[^:]*://')
   cbs build --wait paas7-crio-$CENTOS_SIG_TAG-el7 SRPMS/$PACKAGE-$CENTOS_NVR.el7.src.rpm
   if [ $? -ne 0 ]; then
      cbs tag-pkg paas7-crio-$CENTOS_SIG_TAG-testing $PACKAGE-$CENTOS_NVR.el7
   fi
   popd
   # build fedora module
   cd $MODULE_DIR
   if [ ! -d $MODULE ]; then
      $DIST_PKG clone modules/$MODULE
   fi
   cd $MODULE_DIR/$MODULE
   git checkout $DIST_GIT_TAG
   git commit --allow-empty -asm 'autobuilt latest'
   git push -u origin $DIST_GIT_TAG
   $DIST_PKG module-build
}
