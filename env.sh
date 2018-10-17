#!/bin/sh

export REPO_DIR=~/repositories
export PKG_DIR=~/repositories/pkgs/rhel
#export DIST=$(rpm --eval %{?dist})
#export DISTRO="rhel"
#export DIST_PKG="rhpkg"
#export BUILDDEP="dnf builddep"

while getopts ":t:p:k:b:" opt; do
    case $opt in
        p)
            export PACKAGE=$OPTARG
            ;;
        b)
            export UPSTREAM_BRANCH=$OPTARG
            ;;
    esac
done
