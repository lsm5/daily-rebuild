#!/bin/sh

export REPO_DIR=~/repositories
export PKG_DIR=~/repositories/pkgs

while getopts ":p:d:b:k:" opt; do
    case $opt in
        p)
            export PACKAGE=$OPTARG
            echo "You chose package: $PACKAGE"
            ;;
        d)
            export DISTRO=$OPTARG
            echo "You chose distro: $DISTRO"
            ;;
        b)
            export BRANCH=$OPTARG
            echo "You chose docker branch: $BRANCH"
            ;;
        k)
            export KOJI_TAG=$OPTARG
            if [ $KOJI_TAG == 'rawhide' ]; then
                export DIST_GIT_TAG="master"
            else
                export DIST_GIT_TAG=$KOJI_TAG
            fi
            echo "You chose dist-git tag: $DIST_GIT_TAG"
            ;;
    esac
sleep 3
done
