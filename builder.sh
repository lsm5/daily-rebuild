#!/bin/sh

. env.sh

. pkgs/$PACKAGE.sh
update_sources_and_spec

. common.sh
cleanup_stale
fetch_and_build
