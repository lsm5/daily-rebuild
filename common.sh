#!/bin/sh

. env.sh

# delete stale packages, tarballs and build dirs
cleanup_stale ()
{
    pushd $PKG_DIR/docker
    rm -rf *.tar.gz RPMS SRPMS BUILD*
    popd
}

# update sources
update_sources ()
{
    pushd $REPO_DIR/docker/docker
    git fetch origin
    git fetch rhatdan
    popd

    pushd $REPO_DIR/projectatomic/docker-storage-setup
    git fetch origin
    popd

    pushd $REPO_DIR/fedora-cloud/docker-selinux
    git fetch origin
    popd

    pushd $REPO_DIR/vbatts/docker-utils
    git fetch origin
    popd
}

# conditional rebase if rawhide

# fetch commit values
fetch_commit ()
{
    pushd $REPO_DIR/docker/docker
    git checkout $BRANCH
    echo "Checked out branch: " $BRANCH
    export D_COMMIT=$(git show --pretty=%H -s)
    export D_SHORTCOMMIT=$(c=$D_COMMIT; echo ${c:0:7})
    export VERSION=$(sed -e 's/-.*//' VERSION)
    popd

    pushd $REPO_DIR/fedora-cloud/docker-selinux
    export DS_COMMIT=$(git show --pretty=%H -s)
    export DS_SHORTCOMMIT=$(c=$DS_COMMIT; echo ${c:0:7})
    popd

    pushd $REPO_DIR/projectatomic/docker-storage-setup
    export DSS_COMMIT=$(git show --pretty=%H -s)
    export DSS_SHORTCOMMIT=$(c=$DSS_COMMIT; echo ${c:0:7})
    popd

    pushd $REPO_DIR/vbatts/docker-utils
    export UTILS_COMMIT=$(git show --pretty=%H -s)
    export UTILS_SHORTCOMMIT=$(c=$UTILS_COMMIT; echo ${c:0:7})
    popd
}

# update commit values in spec
update_spec ()
{
    pushd $PKG_DIR/docker
    git checkout $DIST_GIT_TAG
    sed -i "s/\%global d_commit.*/\%global d_commit $D_COMMIT/" docker.spec
    sed -i "s/\%global ds_commit.*/\%global ds_commit $DS_COMMIT/" docker.spec
    sed -i "s/\%global dss_commit.*/\%global dss_commit $DSS_COMMIT/" docker.spec

    echo "- built docker @$BRANCH commit#$D_SHORTCOMMIT" > /tmp/docker.changelog
    echo "- built docker-selinux master commit#$DS_SHORTCOMMIT" >> /tmp/docker.changelog
    echo "- built d-s-s master commit#$DSS_SHORTCOMMIT" >> /tmp/docker.changelog
    echo "- built docker-utils master commit#$UTILS_SHORTCOMMIT" >> /tmp/docker.changelog
    rpmdev-bumpspec -c "$(cat /tmp/docker.changelog)" docker.spec
    popd
}

# update spec changelog and release value
bump_spec ()
{
    pushd $PKG_DIR/docker
    export CURRENT_VERSION=$(cat docker.spec | grep "Version:" | \
        sed -e "s/Version: //")
    if [ "$CURRENT_VERSION" == "$VERSION" ]; then
        rpmdev-bumpspec -c "built docker @lsm5/fedora commit#$D_SHORTCOMMIT"  docker.spec
    else
        rpmdev-bumpspec -n $VERSION -c "New version: $VERSION, built docker \
            @lsm5/commit#$D_SHORTCOMMIT" docker.spec
        sed -i "s/Release: 1\%{?dist}/Release: 1.git\%{d_shortcommit}\%{?dist}/" docker.spec
    fi
    popd
}

# rpmbuild
fetch_and_build ()
{
    pushd $PKG_DIR/docker
    git checkout $DIST_GIT_TAG
    export RELEASE=$(cat docker.spec | grep "Release:" | \
        sed -e "s/Release: //")
    #bump_spec
    spectool -g docker.spec
    sudo dnf builddep docker.spec -y
    rpmbuild -ba docker.spec
    git reset --hard
    fedpkg import --skip-diffs SRPMS/*
    export NVR=$(ls SRPMS | sed -e "s/\.fc.*//")
    git commit -as -m "NVR: $NVR" -m "$(cat /tmp/docker.changelog)"
    popd
}

# if rebase fails, email patch author with output of 'git diff'
# abort the rebase and exit
email_if_rebase_failure ()
{
    if [ $? -eq 1 ]
    then
        export FAILED_PATCH_AUTHOR=$(head -2 .git/rebase-apply/author-script \
            | tail -1 | sed -e "s/GIT_AUTHOR_EMAIL='//" -e "s/'//")
        git diff > /tmp/failed-rebase.txt
        echo 'Emailing author of failed patch...'
        #mutt -F ~/.rmail-muttrc -s 'Daily rebuild: rebase FAIL!' $FAILED_PATCH_AUTHOR \
        #    -c appinfra-docker-team@redhat.com < /tmp/failed-rebase.txt
        git rebase --abort
        echo 'Exiting after failed rebase...'
        exit
    fi
}

misc_function ()
{
# build rpm
rpmbuild -ba docker.spec 2> /tmp/rpmbuild.log

# if rpmbuild fails, email team with last 10 lines of rpmbuild error and
# exit, proceed if rpmbuild successful
if [ $? -eq 1 ]
then
    tail -n 10 /tmp/rpmbuild.log > /tmp/rpmbuild.txt
 #   mutt -F ~/.rmail-muttrc -s 'Daily rebuild: rpmbuild FAIL!' \
  #      appinfra-docker-team@redhat.com < /tmp/rpmbuild.txt
    git reset --hard
    echo 'Exiting after failed rpmbuild...'
    exit
fi
}

# print all golang paths
# for each golang path, if it exists in spec file, continue
# else, add the golang path just below the Summary: line
# (skip vendor/ paths)
update_go_provides ()
{
    pushd $REPO_DIR/docker/docker
    rm -rf vendor
    for line in $(gofed inspect -p)
        do
            if grep -Fxq "Provides: golang(%{import_path}/$line) = %{version}-%{release}" \
                $PKG_DIR/docker/docker.spec
            then
                continue
            else
                sed -i "/Summary:  A golang registry/a Provides: golang(%{import_path}/$line) = %{version}-%{release}" \
                    $PKG_DIR/docker/docker.spec
            fi
        done
    popd
}
