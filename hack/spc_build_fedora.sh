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

echo "Decrypting SSH private key..."
cd $HOME/.ssh
openssl enc -aes-256-cbc -pbkdf2 -d -in id_rsa.enc -out id_rsa -pass pass:$DECRYPTION_PASSPHRASE
echo "Setting correct permissions for SSH private key..."
chmod 600 $HOME/.ssh/id_rsa

# install deps
echo "Updating image and deps..."
sudo dnf -y update --best --allowerasing

echo "Fedora kerberos authentication..."
echo $FEDORA_KRB_PASSWORD | kinit lsm5@FEDORAPROJECT.ORG

echo "Creating pkg dir..."
mkdir -p $HOME/repositories/pkgs

echo "Building $PKG..."
cd $HOME/repositories/pkgs
fedpkg clone $PKG
cd $HOME/daily-rebuild
bash builder.sh -t tagged -p $PKG

echo "$PKG build done!!!"
