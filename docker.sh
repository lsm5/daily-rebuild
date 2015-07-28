#!/bin/sh

# enter docker rpm dir
cd ~/repositories/pkgs/fedora/docker

# delete stale packages, tarballs and build dirs
rm -rf *.tar.gz RPMS SRPMS BUILD*

# checkout rpm master branch and pull from remote
git checkout master
git pull

# fetch docker sources from upstream and rhatdan
cd ~/repositories/github.com/docker/docker
git fetch origin
git fetch rhatdan
git checkout rhatdan/fedora-1.8
git rebase origin/master

# if rebase fails, email patch author with output of 'git diff'
# abort the rebase and exit
if [ $? -eq 1 ]
then
    export FAILED_PATCH_AUTHOR=$(head -2 .git/rebase-apply/author-script \
        | tail -1 | sed -e "s/GIT_AUTHOR_EMAIL='//" -e "s/'//")
    git diff > /tmp/failed-rebase.txt
    echo 'Emailing author of failed patch...'
    mutt -F ~/.rmail-muttrc -s 'Daily rebuild: rebase FAIL!' $FAILED_PATCH_AUTHOR \
        -c appinfra-docker-team@redhat.com < /tmp/failed-rebase.txt
    git rebase --abort
    echo 'Exiting after failed rebase...'
    exit
fi

# delete old fedora branch
git branch -D fedora-1.8

# create new 'fedora' branch from rebased branch
git checkout -b fedora-1.8

# force push new fedora to @lsm5 remote
git push -u lsm5 fedora-1.8 -f

# export commit and version values
export D_COMMIT=$(git show --pretty=%H -s)
export D_SHORTCOMMIT=$(c=$D_COMMIT; echo ${c:0:7})
export VERSION=$(sed -e 's/-.*//' VERSION)

# fetch docker-selinux and docker-storage-setup info
cd ~/repositories/github.com/fedora-cloud/docker-selinux
git fetch origin
export DS_COMMIT=$(git log origin/master -1 --pretty=%H -s)
export DS_SHORTCOMMIT=$(c=$DS_COMMIT; echo ${c:0:7})

cd ~/repositories/github.com/projectatomic/docker-storage-setup
git fetch origin
export DSS_COMMIT=$(git log origin/master -1 --pretty=%H -s)
export DSS_SHORTCOMMIT=$(c=$DSS_COMMIT; echo ${c:0:7})

cd ~/repositories/pkgs/fedora/docker

# get current version in rpm
export CURRENT_VERSION=$(cat docker.spec | grep "Version:" | \
    sed -e "s/Version: //")

# update spec files with latest values
sed -i "s/\%global d_commit.*/\%global d_commit $D_COMMIT/" docker.spec
sed -i "s/\%global ds_commit.*/\%global ds_commit $DS_COMMIT/" docker.spec
sed -i "s/\%global dss_commit.*/\%global dss_commit $DSS_COMMIT/" docker.spec

# fetch docker master branch tarball
spectool -g docker.spec

# install deps
sudo dnf builddep -y docker.spec

# update spec changelog and release value
if [ "$CURRENT_VERSION" == "$VERSION" ]; then
    rpmdev-bumpspec -c "built docker @lsm5/fedora commit#$D_SHORTCOMMIT"  docker.spec
else
    rpmdev-bumpspec -n $VERSION -c "New version: $VERSION, built docker \
        @lsm5/commit#$D_SHORTCOMMIT" docker.spec
    sed -i "s/Release: 1\%{?dist}/Release: 1.git\%{d_shortcommit}\%{?dist}/" docker.spec
fi

export RELEASE=$(cat docker.spec | grep "Release:" | \
    sed -e "s/Release: //")

# build rpm without running check
rpmbuild -ba docker.spec --nocheck 2> /tmp/rpmbuild.log

# if rpmbuild fails, email team with last 10 lines of rpmbuild error and
# exit, proceed if rpmbuild successful
if [ $? -eq 1 ]
then
    tail -n 10 /tmp/rpmbuild.log > /tmp/rpmbuild.txt
    mutt -F ~/.rmail-muttrc -s 'Daily rebuild: rpmbuild FAIL!' \
        appinfra-docker-team@redhat.com < /tmp/rpmbuild.txt
    git reset --hard
    echo 'Exiting after failed rpmbuild...'
    exit
fi

pushd BUILD/docker-$D_COMMIT
rm -rf vendor

# print all golang paths
# for each golang path, if it exists in spec file, continue
# else, add the golang path just below the Summary: line
# (skip vendor/ paths)
for line in $(gofed inspect -p)
do
    if grep -Fxq "Provides: golang(%{import_path}/$line) = %{version}-%{release}" \
        ~/repositories/pkgs/fedora/docker/docker.spec
    then
        continue
    else
        sed -i "/Summary:  A golang registry/a Provides: golang(%{import_path}/$line) = %{version}-%{release}" \
            ~/repositories/pkgs/fedora/docker/docker.spec
    fi
done

popd

# reset everything before import
git reset --hard

#-------
# Fedora
#-------

# fedpkg import SRPM
fedpkg import --skip-diffs SRPMS/docker-$VERSION-*.src.rpm

# get NVR
export NVR=$(ls SRPMS | sed -e "s/\.fc.*//")

# commit changes after importing
git commit -asm "NVR: $NVR"

# push changes to github master
git push -u github master

# push changes to dist-git master
git push -u origin master

# sleep 10 seconds to let koji recognize the latest NVR
sleep 10

# build package in koji
fedpkg build

#-------
# CentOS
#-------

# remove stale docker-master.spec
rm docker-master.spec

# copy latest docker.spec to docker-master.spec
cp docker.spec docker-master.spec

# change package name for docker-master
sed -i "s/Name: \%{repo}/Name: \%{repo}-master/" docker-master.spec

# docker-master Provides: docker
sed -i "/Name: %{repo}-master/a Provides: %{repo} = %{version}-%{release}" \
    docker-master.spec

# modify build tags for el7
sed -i 's/selinux\"/selinux btrfs_noversion\"/' docker-master.spec

# build for el7
rpmbuild --define 'dist .el7' -ba docker-master.spec --nocheck

# ckoji is a symlink to koji which uses my CentOS koji config
~/bin/ckoji build virt7-el7 SRPMS/docker-master-*.el7.src.rpm
~/bin/ckoji tag-pkg virt7-docker-master-testing $(ls SRPMS | sed -e "s/\.src.*//")
