#!/bin/sh

# enter docker rpm dir
cd ~/repositories/pkgs/fedora/docker-io

# delete stale packages, tarballs and build dirs
rm -rf *.tar.gz RPMS SRPMS BUILD*

# checkout rpm master branch and pull from remote
git checkout master
git pull

# enter docker dir
cd ~/repositories/github.com/docker/docker

# checkout master branch
git checkout master

# update master branch from remote
git pull


# export commit and version values
export GITCOMMIT=$(git show --pretty=%H)
export SHORTCOMMIT=$(c=$GITCOMMIT; echo ${c:0:7})
export VERSION=$(sed -e 's/-.*//' VERSION)

cd ~/repositories/pkgs/fedora/docker-io

# if existing version in spec file is not equal to latest version, set
# release tag value 0
export CURRENT_VERSION=$(cat docker-io.spec | grep "Version:" | \
    sed -e "s/Version:\t//")

# update spec files with latest values
sed -i "s/\%global commit.*/\%global commit\t\t$GITCOMMIT/" docker-io.spec

# fetch docker master branch tarball
spectool -g docker-io.spec

# install deps
sudo yum-builddep -y docker-io.spec

# update spec changelog and release value
if [ "$CURRENT_VERSION" == "$VERSION" ]; then
    rpmdev-bumpspec -c "built commit#$SHORTCOMMIT" docker-io.spec
else
    rpmdev-bumpspec -n $VERSION -c "New version: $VERSION, built commit#$SHORTCOMMIT" docker-io.spec
    sed -i "s/Release:    1\%{?dist}/Release:\t1.git\%{shortcommit}\%{?dist}/" docker-io.spec
fi

export RELEASE=$(cat docker-io.spec | grep "Release:" | \
    sed -e "s/Release:\t//")

# build rpm without running check
rpmbuild -ba docker-io.spec --nocheck

pushd BUILD/docker-$GITCOMMIT
rm -rf vendor

# print all golang paths
# for each golang path, if it exists in spec file, continue
# else, add the golang path just below the Summary: line
# (skip vendor/ paths)
for line in $(go2fed inspect -p)
do
    if grep -Fxq "Provides: golang(%{import_path}/$line) = %{version}-%{release}" \
        ~/repositories/pkgs/fedora/docker-io/docker-io.spec
    then
        continue
    else
        sed -i "/Summary:  A golang registry/a Provides: golang(%{import_path}/$line) = %{version}-%{release}" \
            ~/repositories/pkgs/fedora/docker-io/docker-io.spec
    fi
done

popd

# reset everything before import
git reset --hard

#-------
# Fedora
#-------

# fedpkg import SRPM
fedpkg import --skip-diffs SRPMS/docker-io-$VERSION-*.src.rpm

# get NVR
pushd SRPMS
export NVR=$(ls | sed -e "s/\.fc.*//")
popd

# commit changes after importing
git commit -asm "NVR: $NVR"

# push changes to github master
git push -u github master

# push changes to dist-git master
git push -u origin master

# build package in koji
fedpkg build

#-------
# CentOS
#-------

# remove stale docker-master.spec
rm docker-master.spec

# copy latest docker-io.spec to docker-master.spec
cp docker-io.spec docker-master.spec

# change package name for docker-master
sed -i "s/\%{repo}-io/docker-master/" docker-master.spec

# modify build tags for el7
sed -i 's/selinux\"/selinux btrfs_noversion\"/' docker-master.spec

# build for el7
rpmbuild --define 'dist .el7' -ba docker-master.spec --nocheck

# send to CBS (ckbuild = koji build virt7-el7)
~/bin/ckoji build virt7-el7 SRPMS/docker-master-*.el7.src.rpm
