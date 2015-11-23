#!/bin/sh

. env.sh

# update sources
update_sources_and_spec ()
{
    pushd $REPO_DIR/$PACKAGE
    git fetch --all
    git checkout $BRANCH
    export COMMIT=$(git show --pretty=%H -s)
    export SHORTCOMMIT=$(c=$COMMIT; echo ${c:0:7})
    export VERSION=$(cat setup.py | grep version | \
        sed -e "s/__version__ = '//" \
        -e "s/',//" \
        -e "s/    //" \
        -e "s/'//")
    popd

    pushd $PKG_DIR/$PACKAGE
    git checkout $DIST_GIT_TAG
    sed -i "s/\%global commit.*/\%global commit $COMMIT/" $PACKAGE.spec

    echo "- built $PACKAGE commit#$SHORTCOMMIT" > /tmp/$PACKAGE.changelog
    popd
}


#-------
# CentOS
#-------

# remove stale docker-master.spec
#rm docker-master.spec

# copy latest docker.spec to docker-master.spec
#cp docker.spec docker-master.spec

# change package name for docker-master
#sed -i "s/Name: \%{repo}/Name: \%{repo}-master/" docker-master.spec

# docker-master Provides: docker
#sed -i "/Name: %{repo}-master/a Provides: %{repo} = %{version}-%{release}" \
#    docker-master.spec

# modify build tags for el7
#sed -i 's/selinux\"/selinux btrfs_noversion\"/' docker-master.spec

# build for el7
#rpmbuild --define 'dist .el7' -ba docker-master.spec --nocheck

# ckoji is a symlink to koji which uses my CentOS koji config
#~/bin/ckoji build virt7-el7 SRPMS/docker-master-*.el7.src.rpm
#~/bin/ckoji tag-pkg virt7-docker-master-testing $(ls SRPMS | sed -e "s/\.src.*//")
