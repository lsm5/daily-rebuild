#!/bin/sh

export REPO_DIR=~/repositories
export PKG_DIR=~/repositories/pkgs
export DIST=$(rpm --eval %{?dist})

while getopts ":p:d:b:k:" opt; do
    case $opt in
        p)
            export PACKAGE=$OPTARG
            echo "You chose package: $PACKAGE"
            if [ $PACKAGE == 'docker-io' ]; then
                export UPSTREAM="docker"
            else
                export UPSTREAM=$PACKAGE
            fi
            ;;
        d)
            export DISTRO=$OPTARG
            echo "You chose distro: $DISTRO"
            if [ $DISTRO == 'fedora' ]; then
                export DIST_PKG="fedpkg"
            elif [ $DISTRO == 'rhel' ]; then
                export DIST_PKG="rhpkg"
            fi
            ;;
        b)
            export BRANCH=$OPTARG
            echo "You chose $PACKAGE branch: $BRANCH"
            ;;
        k)
            export KOJI_TAG=$OPTARG
            if [ $KOJI_TAG == 'rawhide' ]; then
                export DIST_GIT_TAG="master"
                export DS_BRANCH="fedora-1.9"
            else
                export DIST_GIT_TAG=$KOJI_TAG
                export DS_BRANCH="rhel-1.9"
            fi
            echo "You chose dist-git tag: $DIST_GIT_TAG"
            ;;
    esac
sleep 3
done
