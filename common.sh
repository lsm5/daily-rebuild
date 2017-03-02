#!/bin/sh

. env.sh

# delete stale packages, tarballs and build dirs
cleanup_stale ()
{
    pushd $PKG_DIR/$PACKAGE
    git clean -dfx
    popd
}

# update spec changelog and release value
bump_spec ()
{
    if [ $PACKAGE == 'docker' ]; then
        export CURRENT_VERSION=$(cat $PACKAGE.spec | grep "Version:" | \
            sed -e "s/Version: //")
        if [ "$CURRENT_VERSION" == "$VERSION" ]; then
            rpmdev-bumpspec -c "$(cat /tmp/$PACKAGE.changelog)" $PACKAGE.spec
        else
            rpmdev-bumpspec -n $VERSION -c "$(cat /tmp/$PACKAGE.changelog)" $PACKAGE.spec
            sed -i "s/Release: 1\%{?dist}/Release: 1.git\%{shortcommit0}\%{?dist}/" $PACKAGE.spec
            sed -i "s/$VERSION-1/$VERSION-1.git$SHORTCOMMIT/g" $PACKAGE.spec
        fi
    else
        rpmdev-bumpspec -c "$(cat /tmp/$PACKAGE.changelog)" $PACKAGE.spec
    fi
}

# rpmbuild
fetch_and_build ()
{
    pushd $PKG_DIR/$PACKAGE
    git checkout $DIST_GIT_TAG
    bump_spec
    spectool -g $PACKAGE.spec
    sudo $BUILDDEP $PACKAGE.spec -y
    rpmbuild -ba $PACKAGE.spec
    git reset --hard
    $DIST_PKG import --skip-diffs SRPMS/*
    export NVR=$(grep -A 1 '%changelog' $PACKAGE.spec | sed '$!d' | sed -e "s/[^']* - //")
    git commit -as -m "$PACKAGE-$NVR" -m "$(cat /tmp/$PACKAGE.changelog)"
    popd
}

