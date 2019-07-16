#!/bin/sh

export REPO_DIR=~/repositories
export PKG_DIR=~/repositories/pkgs
export RPM_DOWNLOAD_DIR=~/repositories/rpm-downloads

while getopts ":p:b:k:" opt; do
    case $opt in
        p)
            export PACKAGE=$OPTARG
            ;;
        b)
            export UPSTREAM_BRANCH=$OPTARG
            ;;
    esac
done

if [[ $UPSTREAM_BRANCH == release-1.14 ]]; then
   export DIST_GIT_BRANCH=rhaos-4.2-rhel-8
   export BREW_TAG=rhaos-4.2-rhel-8-candidate
#else
#   export DIST_GIT_BRANCH=private-staging-rhaos-4.0-rhel-7
#   export BREW_TAG=rhaos-4.0-rhel-7-candidate
fi
