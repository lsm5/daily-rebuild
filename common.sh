#!/bin/sh

. env.sh

# delete stale packages, tarballs and build dirs
cleanup_stale ()
{
    if [ -f /tmp/$PACKAGE.changelog ]; then
        rm /tmp/$PACKAGE.changelog
    fi
    pushd $PKG_DIR/$PACKAGE
    git clean -dfx
    popd
}

# update spec changelog and release value
bump_spec ()
{
    pushd $PKG_DIR/$PACKAGE
    git checkout $DIST_GIT_TAG
    echo "DIST_GIT_TAG ===== " $DIST_GIT_TAG
    export CURRENT_COMMIT=$(grep '\%global commit0' $PACKAGE.spec | sed -e 's/\%global commit0 //')
    if [[ $COMMIT == $CURRENT_COMMIT ]]; then
        echo "No change upstream since last build. Exiting..."
        exit 0
    else
        sed -i "s/\%global commit0.*/\%global commit0 $COMMIT/" $PACKAGE.spec
        export CURRENT_VERSION=$(cat $PACKAGE.spec | grep -m 1 "Version:" | sed -e "s/Version: //")
        if [ $CURRENT_VERSION != $VERSION ]; then
            echo "- bump to $VERSION" > /tmp/$PACKAGE.changelog
            echo "- autobuilt $SHORTCOMMIT" >> /tmp/$PACKAGE.changelog
            rpmdev-bumpspec -n $VERSION -c "$(cat /tmp/$PACKAGE.changelog)" $PACKAGE.spec
            sed -i "s/Release: 1\%{?dist}/Release: 1.dev.git\%{shortcommit0}\%{?dist}/" $PACKAGE.spec
            sed -i "s/$VERSION-1/$VERSION-1.dev.git$SHORTCOMMIT/1" $PACKAGE.spec
        else
            echo "- autobuilt $SHORTCOMMIT" >> /tmp/$PACKAGE.changelog
            rpmdev-bumpspec -c "$(cat /tmp/$PACKAGE.changelog)" $PACKAGE.spec
        fi
    fi
}

# rpmbuild
fetch_and_build ()
{
    pushd $PKG_DIR/$PACKAGE
    git checkout $DIST_GIT_TAG
    bump_spec
    spectool -g $PACKAGE.spec
    sudo dnf builddep -y $PACKAGE.spec
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
    $DIST_PKG new-sources *.tar*
    export NVR=$(grep -A 1 '%changelog' $PACKAGE.spec | sed '$!d' | sed -e "s/[^']* - //")
    git commit -as -m "$PACKAGE-$NVR" -m "$(cat /tmp/$PACKAGE.changelog)"
    popd
}

# push and build
push_and_build ()
{
    pushd $PKG_DIR/$PACKAGE
    git push -u origin master
    if [ $? -ne 0 ]; then
        echo "git push FAIL!!!"
        exit 1
    fi
    fedpkg build
    popd
}
