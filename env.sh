#!/bin/sh

export REPO_DIR=~/repositories
export PKG_DIR=~/repositories/pkgs
export DIST=$(rpm --eval %{?dist})
export DISTRO="fedora"
export DIST_PKG="fedpkg"
export BUILDDEP="dnf builddep"

while getopts ":t:p:k:" opt; do
    case $opt in
        t)
            export BUILDTYPE=$OPTARG
            ;;
        p)
            export PACKAGE=$OPTARG
            ;;
        k)
            export DIST_GIT_TAG=$OPTARG
            ;;
    esac
done

if [[ $DIST_GIT_TAG == "f30" ]]; then
   export KOJI_BUILD_SUFFIX=".fc30"
   export CHECK_CENTOS="true"
elif [[ $DIST_GIT_TAG == "f29" ]]; then
   export KOJI_BUILD_SUFFIX=".fc29"
   export CHECK_CENTOS="false"
fi
