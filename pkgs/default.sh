#!/bin/sh

. env.sh

# fetch version and commit info
fetch_version_and_commit ()
{
    pushd $REPO_DIR/$PACKAGE
    git fetch origin
    git checkout origin/master
    if [ $PACKAGE == container-selinux ]; then
       export VERSION=$(cat VERSION)
       echo "VERSION FILE SAYS...." $VERSION
       export COMMIT=$(git show --pretty=%H -s origin/master)
       export SHORTCOMMIT=$(c=$COMMIT; echo ${c:0:7})
       export COMMIT_CENTOS=$(git show --pretty=%H -s origin/RHEL7.5)
       export SHORTCOMMIT_CENTOS=$(c=$COMMIT_CENTOS; echo ${c:0:7})
    else
       export LATEST_TAG=$(git describe --tags --abbrev=0)
       export VERSION=$(echo $LATEST_TAG | sed -e 's/v//')
       export COMMIT=$(git show --pretty=%H -s $(echo $LATEST_TAG))
       export SHORTCOMMIT=$(c=$COMMIT; echo ${c:0:7})
    fi
    popd
}
