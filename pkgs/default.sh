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
    if [ $PACKAGE == atomic ]; then
        export VERSION=$(grep "__version__" Atomic/__init__.py | sed -e 's/__version__ = //' -e "s/'//g")
    elif [ $PACKAGE == buildah ]; then
        export VERSION=$(grep 'Version =' buildah.go | sed -e 's/\tVersion = //' -e 's/"//g' -e 's/-.*//')
    elif [ $PACKAGE == container-selinux ]; then
        export VERSION=$(cat VERSION)
    elif [ $PACKAGE == cri-tools ]; then
        export VERSION=$(grep 'app.Version' cmd/crictl/main.go | sed -e 's/\tapp.Version = //' -e 's/"//g' -e 's/-.*//')
    elif [ $PACKAGE == runc ]; then
        export VERSION=$(cat VERSION | sed -e 's/-.*//')
    else
        export VERSION=$(grep 'const Version' version/version.go | sed -e 's/const Version = "//' -e 's/-.*//')
    fi
    popd
}
