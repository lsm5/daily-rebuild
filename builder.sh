#!/bin/sh

. env.sh
. pkgs/default.sh
fetch_version_and_commit

. common.sh
cleanup_stale
fetch_and_build

commit_to_dist_git
push_and_build
download_from_brew
