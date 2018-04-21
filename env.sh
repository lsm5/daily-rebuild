#!/bin/sh

export REPO_DIR=~/repositories
export PKG_DIR=~/repositories/pkgs
export DIST=$(rpm --eval %{?dist})
export DISTRO="fedora"
export DIST_PKG="fedpkg"
export BUILDDEP="dnf builddep"
export DIST_GIT_TAG="master"

while getopts ":t:p:u:r:k:" opt; do
    case $opt in
        t)
            export BUILDTYPE=$OPTARG
            ;;
        p)
            export PACKAGE=$OPTARG
            ;;
    esac
done
