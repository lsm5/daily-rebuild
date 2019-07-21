#!/bin/sh

export REPO_DIR=~/repositories
export PKG_DIR=~/repositories/pkgs
export DIST=$(rpm --eval %{?dist})
export DISTRO="fedora"
export DIST_PKG="fedpkg"
export BUILDDEP="dnf builddep"
export DIST_GIT_TAG="f30"
export KOJI_BUILD_SUFFIX=".fc30"

while getopts ":t:p:k:" opt; do
    case $opt in
        t)
            export BUILDTYPE=$OPTARG
            ;;
        p)
            export PACKAGE=$OPTARG
            ;;
    esac
done
