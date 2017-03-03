#!/bin/sh

. env.sh
export CR_BRANCH="projectatomic/docker-1.12.4"

# update sources
update_sources_and_spec ()
{
    pushd $REPO_DIR/$PACKAGE
    git fetch --all
    git checkout $BRANCH
    export D_COMMIT=$(git show --pretty=%H -s $BRANCH)
    export D_SHORTCOMMIT=$(c=$D_COMMIT; echo ${c:0:7})
    export VERSION=$(sed -e 's/-.*//' VERSION)
    popd

    #pushd $REPO_DIR/$PACKAGE-storage-setup
    #git fetch origin
    #export DSS_COMMIT=$(git show --pretty=%H -s origin/master)
    #export DSS_SHORTCOMMIT=$(c=$DSS_COMMIT; echo ${c:0:7})
    #popd

    pushd $REPO_DIR/v1.10-migrator
    git fetch origin
    export MIGRATOR_COMMIT=$(git show --pretty=%H -s origin/master)
    export MIGRATOR_SHORTCOMMIT=$(c=$MIGRATOR_COMMIT; echo ${c:0:7})
    popd

    pushd $REPO_DIR/$PACKAGE-novolume-plugin
    git fetch origin
    export NOVOLUME_COMMIT=$(git show --pretty=%H -s origin/master)
    export NOVOLUME_SHORTCOMMIT=$(c=$NOVOLUME_COMMIT; echo ${c:0:7})
    popd

    pushd $REPO_DIR/rhel-push-plugin
    git fetch origin
    export RP_COMMIT=$(git show --pretty=%H -s origin/master)
    export RP_SHORTCOMMIT=$(c=$RP_COMMIT; echo ${c:0:7})
    popd

    pushd $REPO_DIR/$PACKAGE-lvm-plugin
    git fetch origin
    export LVM_COMMIT=$(git show --pretty=%H -s origin/master)
    export LVM_SHORTCOMMIT=$(c=$LVM_COMMIT; echo ${c:0:7})
    popd

    pushd $REPO_DIR/runc
    git fetch origin
    export RUNC_COMMIT=$(git show --pretty=%H -s $BRANCH)
    export RUNC_SHORTCOMMIT=$(c=$RUNC_COMMIT; echo ${c:0:7})
    popd

    pushd $REPO_DIR/containerd
    git fetch origin
    export CD_COMMIT=$(git show --pretty=%H -s $CR_BRANCH)
    export CD_SHORTCOMMIT=$(c=$CD_COMMIT; echo ${c:0:7})
    popd

    pushd $PKG_DIR/$PACKAGE
    git checkout $DIST_GIT_TAG
    sed -i "s/\%global commit_docker.*/\%global commit_docker $D_COMMIT/" $PACKAGE.spec
    #sed -i "s/\%global commit_dss.*/\%global commit_dss $DSS_COMMIT/" $PACKAGE.spec
    sed -i "s/\%global commit_migrator.*/\%global commit_migrator $MIGRATOR_COMMIT/" $PACKAGE.spec
    sed -i "s/\%global commit_novolume.*/\%global commit_novolume $NOVOLUME_COMMIT/" $PACKAGE.spec
    sed -i "s/\%global commit_rhel_push.*/\%global commit_rhel_push $RP_COMMIT/" $PACKAGE.spec
    sed -i "s/\%global commit_lvm.*/\%global commit_lvm $LVM_COMMIT/" $PACKAGE.spec
    sed -i "s/\%global commit_runc.*/\%global commit_runc $RUNC_COMMIT/" $PACKAGE.spec
    sed -i "s/\%global commit_containerd.*/\%global commit_containerd $CD_COMMIT/" $PACKAGE.spec

    echo "- built docker @$BRANCH commit $D_SHORTCOMMIT" > /tmp/$PACKAGE.changelog
    #echo "- built d-s-s commit $DSS_SHORTCOMMIT" >> /tmp/$PACKAGE.changelog
    echo "- built v1.10-migrator commit $MIGRATOR_SHORTCOMMIT" >> /tmp/$PACKAGE.changelog
    echo "- built docker-novolume-plugin commit $NOVOLUME_SHORTCOMMIT" >> /tmp/$PACKAGE.changelog
    echo "- built rhel-push-plugin commit $RP_SHORTCOMMIT" >> /tmp/$PACKAGE.changelog
    echo "- built docker-lvm-plugin commit $LVM_SHORTCOMMIT" >> /tmp/$PACKAGE.changelog
    echo "- built docker-runc @$BRANCH commit $RUNC_SHORTCOMMIT" >> /tmp/$PACKAGE.changelog
    echo "- built docker-containerd @$CR_BRANCH commit $CD_SHORTCOMMIT" >> /tmp/$PACKAGE.changelog

    popd
}
