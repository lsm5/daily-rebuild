#!/bin/sh

. env.sh
export PACKAGE_REPO="docker"
export CR_BRANCH="projectatomic/docker-1.13.0"
#export DEFAULT_BRANCH="projectatomic/docker-1.13.1"

# update sources
update_sources_and_spec ()
{
    pushd $REPO_DIR/$PACKAGE_REPO
    git remote add $USER git://github.com/$USER/$USER_REPO.git
    git fetch $USER
    git checkout $USER/$BRANCH
    export COMMIT_DOCKER=$(git show --pretty=%H -s $USER/$BRANCH)
    export SHORTCOMMIT_DOCKER=$(c=$COMMIT_DOCKER; echo ${c:0:7})
    export VERSION=$(sed -e 's/-.*//' VERSION)
    popd

    #pushd $REPO_DIR/$PACKAGE-storage-setup
    #git fetch origin
    #export DSS_COMMIT=$(git show --pretty=%H -s origin/master)
    #export DSS_SHORTCOMMIT=$(c=$DSS_COMMIT; echo ${c:0:7})
    #popd

    pushd $REPO_DIR/v1.10-migrator
    git fetch origin
    export COMMIT_MIGRATOR=$(git show --pretty=%H -s origin/master)
    export SHORTCOMMIT_MIGRATOR=$(c=$COMMIT_MIGRATOR; echo ${c:0:7})
    popd

    pushd $REPO_DIR/runc
    git fetch origin
    export COMMIT_RUNC=$(git show --pretty=%H -s $USER/$BRANCH)
    export SHORTCOMMIT_RUNC=$(c=$COMMIT_RUNC; echo ${c:0:7})
    popd

    pushd $REPO_DIR/containerd
    git fetch origin
    export COMMIT_CONTAINERD=$(git show --pretty=%H -s $CR_BRANCH)
    export SHORTCOMMIT_CONTAINERD=$(c=$COMMIT_CONTAINERD; echo ${c:0:7})
    popd

    pushd $REPO_DIR/tini
    git fetch origin
    export COMMIT_TINI=$(git show --pretty=%H -s origin/master)
    export SHORTCOMMIT_TINI=$(c=$COMMIT_TINI; echo ${c:0:7})
    popd

    pushd $REPO_DIR/libnetwork
    git fetch origin
    export COMMIT_LIBNETWORK=$(git show --pretty=%H -s origin/master)
    export SHORTCOMMIT_LIBNETWORK=$(c=$COMMIT_LIBNETWORK; echo ${c:0:7})
    popd

    pushd $PKG_DIR/$PACKAGE
    git checkout $DIST_GIT_TAG
    sed -i "s/\%global git_docker.*/\%global git_docker https:\/\/github.com\/$USER\/$USER_REPO/" $PACKAGE.spec
    sed -i "s/\%global commit_docker.*/\%global commit_docker $COMMIT_DOCKER/" $PACKAGE.spec
    #sed -i "s/\%global commit_dss.*/\%global commit_dss $DSS_COMMIT/" $PACKAGE.spec
    sed -i "s/\%global commit_migrator.*/\%global commit_migrator $COMMIT_MIGRATOR/" $PACKAGE.spec
    sed -i "s/\%global commit_runc.*/\%global commit_runc $COMMIT_RUNC/" $PACKAGE.spec
    sed -i "s/\%global commit_containerd.*/\%global commit_containerd $COMMIT_CONTAINERD/" $PACKAGE.spec
    sed -i "s/\%global commit_tini.*/\%global commit_tini $COMMIT_TINI/" $PACKAGE.spec
    sed -i "s/\%global commit_libnetwork.*/\%global commit_libnetwork $COMMIT_LIBNETWORK/" $PACKAGE.spec



    echo "- built docker @$USER/$BRANCH commit $SHORTCOMMIT_DOCKER" > /tmp/$PACKAGE.changelog
    #echo "- built d-s-s commit $SHORTCOMMIT_DSS" >> /tmp/$PACKAGE.changelog
    echo "- built v1.10-migrator commit $SHORTCOMMIT_MIGRATOR" >> /tmp/$PACKAGE.changelog
    echo "- built docker-runc @$BRANCH commit $SHORTCOMMIT_RUNC" >> /tmp/$PACKAGE.changelog
    echo "- built docker-containerd @$CR_BRANCH commit $SHORTCOMMIT_CONTAINERD" >> /tmp/$PACKAGE.changelog
    echo "- built docker-init commit $SHORTCOMMIT_TINI" >> /tmp/$PACKAGE.changelog
    echo "- built libnetwork commit $SHORTCOMMIT_LIBNETWORK" >> /tmp/$PACKAGE.changelog

    popd
}
