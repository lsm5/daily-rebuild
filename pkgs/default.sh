#!/bin/sh

. $(pwd)/env.sh

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
        export VERSION=$(grep policy_module container.te | cut -b 26- | sed -e 's/)//')
    # containernetworking-plugins
    elif [ $PACKAGE == containernetworking-plugins ]; then
        export VERSION=$(git describe --abbrev=0 --tags | sed -s 's/v//')
    # fuse-overlayfs
    elif [ $PACKAGE == fuse-overlayfs ]; then
        export VERSION=$(grep 'AC_INIT' configure.ac | cut -b 28- | sed -e 's/].*//')
    # runc    
    elif [ $PACKAGE == runc ]; then
        export VERSION=$(cat VERSION | sed -e 's/-.*//')
    # slirp4netns    
    elif [ $PACKAGE == slirp4netns ]; then
        export VERSION=$(grep AC_INIT configure.ac | cut -b 25- | sed -e 's/+dev.*//' -e 's/-.*//' )
    else
        export VERSION=$(grep 'const Version' version/version.go | sed -e 's/const Version = "//' -e 's/-.*//')
    fi
    popd
}
