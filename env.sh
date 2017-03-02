#!/bin/sh

export REPO_DIR=~/repositories
export PKG_DIR=~/repositories/pkgs
export DIST=$(rpm --eval %{?dist})
if [ $DIST == '.el7' ]; then
    export DISTRO="rhel"
    export DIST_PKG="rhpkg"
    export BUILDDEP="yum-builddep"
else
    export DISTRO="fedora"
    export DIST_PKG="fedpkg"
    export BUILDDEP="dnf builddep"
fi

while getopts ":p:b:k:" opt; do
    case $opt in
        p)
            export PACKAGE=$OPTARG
            ;;
        b)
            export BRANCH=$OPTARG
            ;;
        k)
            export KOJI_TAG=$OPTARG
            export DIST_GIT_TAG=$KOJI_TAG
            ;;
    esac
done
