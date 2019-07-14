#!/bin/sh

. env.sh
. pkgs/default.sh
fetch_version_and_commit
. common.sh
#cleanup_stale
fetch_and_build

if [ $BUILDTYPE == "tagged" ]; then
    commit_to_dist_git
    push_and_build
fi
