#!/bin/bash

set -e

if [[ "$SPC" != "true" ]]
then
    echo "This script is intended to be executed in an SPC,"
    echo "by run_ci_tests.sh. Using it otherwise may result"
    echo "in unplesent side-effects."
    exit 1
fi

echo
echo "Build Environment:"
env

set +x

# install deps
echo "Updating image and deps..."
sudo yum -y update

# Setup SSH key
echo "Copying CentOS certs..."
sudo mv $(pwd)/.centos-server-ca.cert /home/lsm5-bot/.centos-server-ca.cert
sudo mv $(pwd)/.centos.cert /home/lsm5-bot/.centos.cert

echo "Own everything in $HOME..."
sudo chown -R lsm5-bot:lsm5-bot /home/lsm5-bot

echo "Set correct permissions for CentOS certs..."
chmod 664 $HOME/.centos-server-ca.cert
chmod 600 $HOME/.centos.cert
ln -s $HOME/.centos-server-ca.cert $HOME/.centos-upload-ca.cert

mkdir -p $HOME/repositories/pkgs
cd $HOME/repositories/pkgs

git clone git://pkgs.fedoraproject.org/rpms/$PKG
cd $PKG
spectool -g $PKG.spec
sudo yum-builddep -y $PKG.spec
rpmbuild --define='dist .el7' -ba $PKG.spec
if [[ $? -ne 0 ]]; then
    echo "rpm build FAIL!!!"
fi
cbs build virt7-container-common-el7 SRPMS/$PKG*.src.rpm
if [[ $? -ne 0 ]]; then
    echo "CBS build FAIL!!!"
fi

export BUILD_ID=$(ls SRPMS | sed -e 's/.src.rpm//')
echo "Tagging into Virt7 testing branch..."
cbs tag-pkg virt7-container-common-testing $BUILD_ID

echo "Done!!!"
