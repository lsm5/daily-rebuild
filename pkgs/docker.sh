#!/bin/sh

. env.sh
export CR_BRANCH="projectatomic/docker-1.12.4"
export DEFAULT_BRANCH="projectatomic/docker-1.12.6"

# update sources
update_sources_and_spec ()
{
    pushd $REPO_DIR/$PACKAGE
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

    pushd $REPO_DIR/$PACKAGE-novolume-plugin
    git fetch origin
    export COMMIT_NOVOLUME=$(git show --pretty=%H -s origin/master)
    export SHORTCOMMIT_NOVOLUME=$(c=$COMMIT_NOVOLUME; echo ${c:0:7})
    popd

    pushd $REPO_DIR/rhel-push-plugin
    git fetch origin
    export COMMIT_RHEL_PUSH=$(git show --pretty=%H -s origin/master)
    export SHORTCOMMIT_RHEL_PUSH=$(c=$COMMIT_RHEL_PUSH; echo ${c:0:7})
    popd

    pushd $REPO_DIR/$PACKAGE-lvm-plugin
    git fetch origin
    export COMMIT_LVM=$(git show --pretty=%H -s origin/master)
    export SHORTCOMMIT_LVM=$(c=$COMMIT_LVM; echo ${c:0:7})
    popd

    pushd $REPO_DIR/runc
    git fetch origin
    export COMMIT_RUNC=$(git show --pretty=%H -s $DEFAULT_BRANCH)
    export SHORTCOMMIT_RUNC=$(c=$COMMIT_RUNC; echo ${c:0:7})
    popd

    pushd $REPO_DIR/containerd
    git fetch origin
    export COMMIT_CONTAINERD=$(git show --pretty=%H -s $CR_BRANCH)
    export SHORTCOMMIT_CONTAINERD=$(c=$COMMIT_CONTAINERD; echo ${c:0:7})
    popd

    pushd $PKG_DIR/$PACKAGE
    git checkout $DIST_GIT_TAG
    sed -i "s/\%global git_docker.*/\%global git_docker https:\/\/github.com\/$USER\/$USER_REPO/" $PACKAGE.spec
    sed -i "s/\%global commit_docker.*/\%global commit_docker $COMMIT_DOCKER/" $PACKAGE.spec
    #sed -i "s/\%global commit_dss.*/\%global commit_dss $DSS_COMMIT/" $PACKAGE.spec
    #sed -i "s/\%global commit_novolume.*/\%global commit_novolume $COMMIT_NOVOLUME/" $PACKAGE.spec
    #sed -i "s/\%global commit_rhel_push.*/\%global commit_rhel_push $COMMIT_RHEL_PUSH/" $PACKAGE.spec
    #sed -i "s/\%global commit_lvm.*/\%global commit_lvm $COMMIT_LVM/" $PACKAGE.spec
    #sed -i "s/\%global commit_runc.*/\%global commit_runc $COMMIT_RUNC/" $PACKAGE.spec
    #sed -i "s/\%global commit_containerd.*/\%global commit_containerd $COMMIT_CONTAINERD/" $PACKAGE.spec

    echo "- built docker @$USER/$BRANCH commit $SHORTCOMMIT_DOCKER" > /tmp/$PACKAGE.changelog
    #echo "- built d-s-s commit $SHORTCOMMIT_DSS" >> /tmp/$PACKAGE.changelog
    #echo "- built docker-novolume-plugin commit $SHORTCOMMIT_NOVOLUME" >> /tmp/$PACKAGE.changelog
    #echo "- built rhel-push-plugin commit $SHORTCOMMIT_RHEL_PUSH" >> /tmp/$PACKAGE.changelog
    #echo "- built docker-lvm-plugin commit $SHORTCOMMIT_LVM" >> /tmp/$PACKAGE.changelog
    #echo "- built docker-runc @$BRANCH commit $SHORTCOMMIT_RUNC" >> /tmp/$PACKAGE.changelog
    #echo "- built docker-containerd @$CR_BRANCH commit $SHORTCOMMIT_CONTAINERD" >> /tmp/$PACKAGE.changelog

    popd
}
