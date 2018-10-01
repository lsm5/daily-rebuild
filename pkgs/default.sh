#!/bin/sh

. env.sh

# fetch version and commit info
fetch_version_and_commit ()
{
    pushd $REPO_DIR/$PACKAGE
    git fetch origin
    git checkout origin/$UPSTREAM_BRANCH
    export COMMIT=$(git show --pretty=%H -s origin/$UPSTREAM_BRANCH)
    export SHORTCOMMIT=$(c=$COMMIT; echo ${c:0:7})
    if [ $PACKAGE == cri-tools ]; then
        export VERSION=$(git describe --tags --dirty --always | sed -e 's/v//' -e 's/-.*//')
    elif [ $PACKAGE == runc ]; then
        export VERSION=$(cat VERSION | sed -e 's/-.*//')
    else
        export VERSION=$(grep 'const Version' version/version.go | sed -e 's/const Version = "//' -e 's/-.*//')
    fi
    popd
}
