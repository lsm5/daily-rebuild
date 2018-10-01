#!/bin/sh

export REPO_DIR=~/repositories
export PKG_DIR=~/repositories/pkgs
export DIST=$(rpm --eval %{?dist})
export DISTRO="rhel"
export DIST_PKG="rhpkg"
export BUILDDEP="yum-builddep"

while getopts ":t:p:k:b:" opt; do
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
        b)
            export UPSTREAM_BRANCH=$OPTARG
            ;;
    esac
done
