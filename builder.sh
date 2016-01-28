#!/bin/sh

. env.sh

. pkgs/$PACKAGE.sh
update_sources_and_spec
update_go_provides

. common.sh
cleanup_stale
fetch_and_build
