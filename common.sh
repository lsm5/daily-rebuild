#!/bin/sh

. env.sh

# update spec changelog and release value
bump_spec ()
{
   pushd $PKG_DIR/$PACKAGE
   git checkout $DIST_GIT_BRANCH
   export CURRENT_COMMIT=$(grep '\%global commit0' $PACKAGE.spec | sed -e 's/\%global commit0 //')
   if [ $COMMIT == $CURRENT_COMMIT ]; then
      echo "No change upstream since last build. Exiting..."
      exit 0
   else
      sed -i "s/\%global commit0.*/\%global commit0 $COMMIT/" $PACKAGE.spec
      export CURRENT_VERSION=$(cat $PACKAGE.spec | grep -m 1 "Version:" | sed -e "s/Version: //")
      if [ $CURRENT_VERSION != $VERSION ]; then
         echo "- bump to $VERSION" > /tmp/$PACKAGE.changelog
         echo "- autobuilt $SHORTCOMMIT" >> /tmp/$PACKAGE.changelog
         sed -i "s/Version: [0-9.]*/Version: $VERSION/" $PACKAGE.spec
         sed -i "s/Release: [0-9]*.nightly/Release: 1.nightly/" $PACKAGE.spec
         sed -i "s/$VERSION-1/$VERSION-1.nightly.git$SHORTCOMMIT/1" $PACKAGE.spec
         rpmdev-bumpspec -c "$(cat /tmp/$PACKAGE.changelog)" $PACKAGE.spec
      else
         echo "- autobuilt $SHORTCOMMIT" >> /tmp/$PACKAGE.changelog
         rpmdev-bumpspec -c "$(cat /tmp/$PACKAGE.changelog)" $PACKAGE.spec
      fi
   fi
}

# rpmbuild
fetch_pkg_and_build ()
{
   pushd $PKG_DIR/$PACKAGE
   git checkout $DIST_GIT_BRANCH
   bump_spec
   spectool -g $PACKAGE.spec
   sudo yum-builddep -y $PACKAGE.spec
   rpmbuild --define='dist .el7' -ba $PACKAGE.spec
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
   rhpkg new-sources *.tar*
   export NVR=$(grep -A 1 '%changelog' $PACKAGE.spec | sed '$!d' | sed -e "s/[^']* - //")
   git commit -as -m "$PACKAGE-$NVR" -m "$(cat /tmp/$PACKAGE.changelog)"
   popd
}

# push and build
push_and_build ()
{
   kinit-lsm5
   pushd $PKG_DIR/$PACKAGE
   git push -u origin $DIST_GIT_BRANCH
   if [ $? -ne 0 ]; then
       echo "git push FAIL!!!"
       exit 1
   fi
   rhpkg scratch-build --target=$BREW_TAG > /tmp/$PACKAGE-brewlog.txt 2>&1
   if [ $? -ne 0 ]; then
      echo "rhpkg build FAIL!!!"
      exit 1
   fi
   popd
}

# download rpm from brew
download_from_brew ()
{
   if [[ $PACKAGE == podman || $PACKAGE == runc || $PACKAGE == containernetworking-plugins ]]; then
      pushd $RPM_DOWNLOAD_DIR/release-1.11
      export TASK_ID=$(grep 'Created task' /tmp/$PACKAGE-brewlog.txt | sed -e 's/Created task: //')
      brew download-task --arch x86_64 $TASK_ID
      popd
      pushd $RPM_DOWNLOAD_DIR/release-1.12
      export TASK_ID=$(grep 'Created task' /tmp/$PACKAGE-brewlog.txt | sed -e 's/Created task: //')
      brew download-task --arch x86_64 $TASK_ID
      popd
   else
      pushd $RPM_DOWNLOAD_DIR/$UPSTREAM_BRANCH
      export TASK_ID=$(grep 'Created task' /tmp/$PACKAGE-brewlog.txt | sed -e 's/Created task: //')
      brew download-task --arch x86_64 $TASK_ID
      popd
   fi
}

# send to openshift mirror
send_to_openshift ()
{
   pushd $RPM_DOWNLOAD_DIR
   scp release-1.11/* openshift-mirror:/srv/enterprise/rhel/cri-o-tested/nightly/1.11/x86_64/os/Packages/
   scp release-1.12/* openshift-mirror:/srv/enterprise/rhel/cri-o-tested/nightly/1.12/x86_64/os/Packages/
   rm -rf release-1.11/* release-1.12/*
   popd
}
