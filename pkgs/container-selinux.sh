#!/bin/sh

. env.sh

# update sources
update_sources_and_spec ()
{
    pushd $REPO_DIR/$PACKAGE
    git remote add $USER git://github.com/$USER/$USER_REPO.git
    git fetch --all
    git checkout $USER/$BRANCH
    export COMMIT=$(git show --pretty=%H -s $USER/$BRANCH)
    export SHORTCOMMIT=$(c=$COMMIT; echo ${c:0:7})
    export VERSION=$(sed -e 's/-.*//' VERSION)
    popd

    pushd $PKG_DIR/$PACKAGE
    git checkout $DIST_GIT_TAG
    sed -i "s/\%global commit0.*/\%global commit0 $COMMIT/" $PACKAGE.spec

    echo "- built @$USER/$BRANCH commit $SHORTCOMMIT" > /tmp/$PACKAGE.changelog
    popd
}
