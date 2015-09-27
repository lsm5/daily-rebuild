#!/bin/sh

. env.sh

# delete stale packages, tarballs and build dirs
cleanup_stale ()
{
    pushd $PKG_DIR/$PACKAGE
    rm -rf *.tar.gz RPMS SRPMS BUILD*
    popd
}

# update sources & spec from $PACKAGE.sh file

# rpmbuild
fetch_and_build ()
{
    pushd $PKG_DIR/$PACKAGE
    git checkout $DIST_GIT_TAG
    rpmdev-bumpspec -c "$(cat /tmp/$PACKAGE.changelog)" $PACKAGE.spec
#    export RELEASE=$(cat $PACKAGE.spec | grep "Release:" | \
#        sed -e "s/Release: //")
    spectool -g $PACKAGE.spec
    sudo dnf builddep $PACKAGE.spec -y
    rpmbuild -ba $PACKAGE.spec
    git reset --hard
    fedpkg import --skip-diffs SRPMS/*
    export NVR=$(ls SRPMS | sed -e "s/\.fc.*//")
    git commit -as -m "NVR: $NVR" -m "$(cat /tmp/$PACKAGE.changelog)"
    popd
}







# update spec changelog and release value
bump_spec ()
{
    pushd $PKG_DIR/$PACKAGE
    export CURRENT_VERSION=$(cat $PACKAGE.spec | grep "Version:" | \
        sed -e "s/Version: //")
    if [ "$CURRENT_VERSION" == "$VERSION" ]; then
        rpmdev-bumpspec -c "built $PACKAGE @lsm5/fedora commit#$D_SHORTCOMMIT"  docker.spec
    else
        rpmdev-bumpspec -n $VERSION -c "New version: $VERSION, built docker \
            @lsm5/commit#$D_SHORTCOMMIT" docker.spec
        sed -i "s/Release: 1\%{?dist}/Release: 1.git\%{d_shortcommit}\%{?dist}/" docker.spec
    fi
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
    pushd $REPO_DIR/docker/$PACKAGE
    rm -rf vendor
    for line in $(gofed inspect -p)
        do
            if grep -Fxq "Provides: golang(%{import_path}/$line) = %{version}-%{release}" \
                $PKG_DIR/docker/$PACKAGE.spec
            then
                continue
            else
                sed -i "/Summary:  A golang registry/a Provides: golang(%{import_path}/$line) = %{version}-%{release}" \
                    $PKG_DIR/docker/$PACKAGE.spec
            fi
        done
    popd
}
