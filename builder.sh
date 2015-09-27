#!/bin/sh

. env.sh

. $PACKAGE.sh
update_sources_and_spec

. common.sh
cleanup_stale
fetch_and_build
