#!/bin/sh

. env.sh

# update sources
update_sources_and_spec ()
{
    pushd $REPO_DIR/$PACKAGE
    git fetch --all
    git checkout $BRANCH
    export COMMIT=$(git show --pretty=%H -s $BRANCH)
    export SHORTCOMMIT=$(c=$COMMIT; echo ${c:0:7})
    export VERSION=$(grep AC_INIT configure.ac | cut -d' ' -f2 \
        | tr -d \]\[, | tr -d +git)
    popd

    pushd $PKG_DIR/$PACKAGE
    git checkout $DIST_GIT_TAG
    sed -i "s/\%global commit0.*/\%global commit0 $COMMIT/" $PACKAGE.spec

    echo "- built commit#$SHORTCOMMIT" > /tmp/$PACKAGE.changelog
    popd
}
