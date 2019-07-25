#!/bin/sh

. $(pwd)/env.sh
. $(pwd)/pkgs/default.sh
fetch_version_and_commit
. $(pwd)/common.sh
fetch_pkg_and_build

if [ $BUILDTYPE == "tagged" ]; then
    commit_to_dist_git
    push_and_build
fi
