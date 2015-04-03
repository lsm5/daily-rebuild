#!/bin/sh

# enter rkt rpm dir
cd ~/repositories/pkgs/wip/rkt

# delete stale packages, tarballs and build dirs
rm -rf *.tar.gz RPMS SRPMS BUILD*

# checkout rpm master branch and pull from remote
git checkout master
git pull

# enter rkt dir
cd ~/repositories/github.com/coreos/rkt

# fetch the latest from rkt upstream
git checkout master
git pull

# export commit and version values
export GITCOMMIT=$(git show --pretty=%H -s)
export SHORTCOMMIT=$(c=$GITCOMMIT; echo ${c:0:7})
export VERSION=$(grep 'const Version' version/version.go \
    | sed -e 's/const Version = "//' -e 's/+git"//')

cd ~/repositories/pkgs/wip/rkt

# get current version in rpm
export CURRENT_VERSION=$(cat rkt.spec | grep "Version:" | \
    sed -e "s/Version: //")

# update spec files with latest values
sed -i "s/\%global commit.*/\%global commit $GITCOMMIT/" rkt.spec

# fetch rkt master branch tarball
spectool -g rkt.spec

# install deps
sudo yum-builddep -y rkt.spec

# update spec changelog and release value
if [ "$CURRENT_VERSION" == "$VERSION" ]; then
    rpmdev-bumpspec -c "built rkt commit#$SHORTCOMMIT"  rkt.spec
else
    rpmdev-bumpspec -n $VERSION -c "New version: $VERSION, built rkt \
        commit#$SHORTCOMMIT" rkt.spec
    sed -i "s/Release: 1\%{?dist}/Release: 1.git\%{d_shortcommit}\%{?dist}/" rkt.spec
fi

export RELEASE=$(cat rkt.spec | grep "Release:" | \
    sed -e "s/Release: //")

# build rpm without running check
rpmbuild -ba rkt.spec --nocheck

#pushd BUILD/rkt-$GITCOMMIT
#rm -rf vendor

# print all golang paths
# for each golang path, if it exists in spec file, continue
# else, add the golang path just below the Summary: line
# (skip vendor/ paths)
#for line in $(go2fed inspect -p)
#do
#    if grep -Fxq "Provides: golang(%{import_path}/$line) = %{version}-%{release}" \
#        ~/repositories/pkgs/wip/rkt/rkt.spec
#    then
#        continue
#    else
#        sed -i "/Summary:  A golang registry/a Provides: golang(%{import_path}/$line) = %{version}-%{release}" \
#            ~/repositories/pkgs/wip/rkt/rkt.spec
#    fi
#done

#popd

# reset everything before import
#git reset --hard

#-------
# Fedora
#-------

# fedpkg import SRPM
#fedpkg import --skip-diffs SRPMS/rkt-$VERSION-*.src.rpm

# get NVR
pushd SRPMS
export NVR=$(ls | sed -e "s/\.fc.*//")
popd

# commit changes after importing
git commit -asm "NVR: $NVR"

# push changes to github master
#git push -u github master

# push changes to fedora-cloud/rkt-rpm master
git push -u origin master

# send SRPM to fedorapeople publicly accessible URL
scp SRPMS/$NVR.fc23.src.rpm fpeople:public_html/rkt/.

# copr build
copr-cli build rkt https://lsm5.fedorapeople.org/rkt/$NVR.fc23.src.rpm

# sleep 10 seconds to let koji recognize the latest NVR
#sleep 10

# build package in koji
#fedpkg build

#-------
# CentOS
#-------

# remove stale rkt-master.spec
#rm rkt-master.spec

# copy latest rkt.spec to rkt-master.spec
#cp rkt.spec rkt-master.spec

# change package name for rkt-master
#sed -i "s/Name: \%{repo}/Name: \%{repo}-master/" rkt-master.spec

# modify build tags for el7
#sed -i 's/selinux\"/selinux btrfs_noversion\"/' rkt-master.spec

# build for el7
#rpmbuild --define 'dist .el7' -ba rkt-master.spec --nocheck

# ckoji is a symlink to koji which uses my CentOS koji config
#~/bin/ckoji build virt7-el7 SRPMS/rkt-master-*.el7.src.rpm
