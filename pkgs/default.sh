#!/bin/sh

. env.sh

# fetch version and commit info
fetch_version_and_commit ()
{
    pushd $REPO_DIR/$PACKAGE
    git fetch origin
    git checkout origin/master
    export COMMIT=$(git show --pretty=%H -s origin/master)
    export SHORTCOMMIT=$(c=$COMMIT; echo ${c:0:7})
    # buildah
    if [ $PACKAGE == buildah ]; then
        export VERSION=$(grep 'Version =' buildah.go | sed -e 's/\tVersion = //' -e 's/"//g' -e 's/-.*//')
    # container-selinux  
    elif [ $PACKAGE == container-selinux ]; then
        export VERSION=$(cat VERSION)
    # runc    
    elif [ $PACKAGE == runc ]; then
        export VERSION=$(cat VERSION | sed -e 's/-.*//')
    # container-storage-setup
    elif [ $PACKAGE == container-storage-setup ]; then
        export MAJOR_VERSION=$(grep '_CSS_MAJOR_VERSION=' $PACKAGE.sh | sed -e 's/_CSS_MAJOR_VERSION=//' -e 's/"//g')
        export MINOR_VERSION=$(grep '_CSS_MINOR_VERSION=' $PACKAGE.sh | sed -e 's/_CSS_MINOR_VERSION=//' -e 's/"//g')
        export SUBLEVEL=$(grep '_CSS_SUBLEVEL=' $PACKAGE.sh | sed -e 's/_CSS_SUBLEVEL=//' -e 's/"//g')
        export VERSION=$MAJOR_VERSION.$MINOR_VERSION.$SUBLEVEL
    # fuse-overlayfs
    elif [ $PACKAGE == fuse-overlayfs ]; then
        export VERSION=$(grep 'AC_INIT' configure.ac | cut -b 28- | sed -e 's/].*//')
    # containernetworking-plugins
    elif [ $PACKAGE == containernetworking-plugins ]; then
        export VERSION=$(git describe --abbrev=0 --tags | sed -s 's/v//')
    else
        export VERSION=$(grep 'const Version' version/version.go | sed -e 's/const Version = "//' -e 's/-.*//')
    fi
    popd
}
