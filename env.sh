#!/bin/sh

export REPO_DIR=~/repositories
export PKG_DIR=~/repositories/pkgs
export MODULE_DIR=~/repositories/modules
export MODULE=cri-o
export DIST=$(rpm --eval %{?dist})
export DISTRO="fedora"
export DIST_PKG="fedpkg"
export BUILDDEP="dnf builddep"

while getopts ":b:p:t:" opt; do
    case $opt in
        b)
            export UPSTREAM_BRANCH=$OPTARG
            ;;
        p)
            export PACKAGE=$OPTARG
            ;;
        t)
            export BUILDTYPE=$OPTARG
            ;;
    esac
done

if [[ $UPSTREAM_BRANCH == release-1.11 ]]; then
   export DIST_GIT_TAG=1.11
elif [[ $UPSTREAM_BRANCH == release-1.12 ]]; then
   export DIST_GIT_TAG=1.12
elif [[ $UPSTREAM_BRANCH == release-1.13 ]]; then
   export DIST_GIT_TAG=1.13
elif [[ $UPSTREAM_BRANCH == release-1.14 ]]; then
   export DIST_GIT_TAG=1.14
elif [[ $UPSTREAM_BRANCH == release-1.15 ]]; then
   export DIST_GIT_TAG=1.15
fi
export CENTOS_SIG_TAG=$(echo $DIST_GIT_TAG | sed -e 's/\.//')
