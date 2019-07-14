#!/bin/sh

export REPO_DIR=/home/lsm5-bot/repositories
export PKG_DIR=/home/lsm5-bot/repositories/pkgs
export DIST=$(rpm --eval %{?dist})
export DISTRO="fedora"
export DIST_PKG="fedpkg"
export BUILDDEP="dnf builddep"
export DIST_GIT_TAG="f30"

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
