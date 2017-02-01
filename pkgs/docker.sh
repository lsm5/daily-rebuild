#!/bin/sh

. env.sh

export DS_BRANCH="RHEL-1.12"
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

    pushd $REPO_DIR/$PACKAGE-storage-setup
    git fetch origin
    export DSS_COMMIT=$(git show --pretty=%H -s origin/master)
    export DSS_SHORTCOMMIT=$(c=$DSS_COMMIT; echo ${c:0:7})
    popd

    pushd $REPO_DIR/container-selinux
    git fetch origin
    export DS_COMMIT=$(git show --pretty=%H -s origin/$DS_BRANCH)
    export DS_SHORTCOMMIT=$(c=$DS_COMMIT; echo ${c:0:7})
    popd

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
    sed -i "s/\%global commit0.*/\%global commit0 $D_COMMIT/" $PACKAGE.spec
    sed -i "s/\%global commit1.*/\%global commit1 $DS_COMMIT/" $PACKAGE.spec
    sed -i "s/\%global commit2.*/\%global commit2 $DSS_COMMIT/" $PACKAGE.spec
    sed -i "s/\%global commit3.*/\%global commit3 $MIGRATOR_COMMIT/" $PACKAGE.spec
    sed -i "s/\%global commit4.*/\%global commit4 $NOVOLUME_COMMIT/" $PACKAGE.spec
    sed -i "s/\%global commit5.*/\%global commit5 $RP_COMMIT/" $PACKAGE.spec
    sed -i "s/\%global commit6.*/\%global commit6 $LVM_COMMIT/" $PACKAGE.spec
    sed -i "s/\%global commit7.*/\%global commit7 $RUNC_COMMIT/" $PACKAGE.spec
    sed -i "s/\%global commit8.*/\%global commit8 $CD_COMMIT/" $PACKAGE.spec

    echo "- built docker @$BRANCH commit $D_SHORTCOMMIT" > /tmp/$PACKAGE.changelog
    echo "- built container-selinux commit $DS_SHORTCOMMIT" >> /tmp/$PACKAGE.changelog
    echo "- built d-s-s commit $DSS_SHORTCOMMIT" >> /tmp/$PACKAGE.changelog
    echo "- built v1.10-migrator commit $MIGRATOR_SHORTCOMMIT" >> /tmp/$PACKAGE.changelog
    echo "- built docker-novolume-plugin commit $NOVOLUME_SHORTCOMMIT" >> /tmp/$PACKAGE.changelog
    echo "- built rhel-push-plugin commit $RP_SHORTCOMMIT" >> /tmp/$PACKAGE.changelog
    echo "- built docker-lvm-plugin commit $LVM_SHORTCOMMIT" >> /tmp/$PACKAGE.changelog
    echo "- built docker-runc commit $RUNC_SHORTCOMMIT" >> /tmp/$PACKAGE.changelog
    echo "- built docker-containerd commit $CD_SHORTCOMMIT" >> /tmp/$PACKAGE.changelog
    popd
}
