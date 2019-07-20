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
      # cleanup previous /tmp changelog entries
      if [ -f /tmp/$PACKAGE.changelog ]; then
         rm -f /tmp/$PACKAGE.changelog
      fi

      if [ $CURRENT_VERSION != $VERSION ]; then
         echo "- bump to $VERSION" > /tmp/$PACKAGE.changelog
         echo "- autobuilt $SHORTCOMMIT" >> /tmp/$PACKAGE.changelog
         sed -i "s/Version: [0-9.]*/Version: $VERSION/" $PACKAGE.spec
         sed -i "s/Release: [0-9]*.dev/Release: 0.0.dev/" $PACKAGE.spec
         sed -i "s/$VERSION-0.0/$VERSION-0.0.dev.git$SHORTCOMMIT/1" $PACKAGE.spec
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
   cd $PKG_DIR
   if [ ! -d $PACKAGE ]; then
      $DIST_PKG clone $PACKAGE
   fi
   pushd $PKG_DIR/$PACKAGE
   git checkout $DIST_GIT_TAG
   bump_spec
   spectool -g $PACKAGE.spec
   sudo $BUILDDEP -y $PACKAGE.spec
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
   if [ $? -ne 0 ]; then
       echo "git push FAIL!!!"
       exit 1
   fi
   popd
}
