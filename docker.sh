#!/bin/sh

. common.sh

cleanup_stale
update_sources
fetch_commit
update_spec
update_go_provides
fetch_and_build


#-------
# Fedora
#-------

# get NVR
#export NVR=$(ls SRPMS | sed -e "s/\.fc.*//")

# commit changes after importing
#git commit -asm "NVR: $NVR"

# push changes to github master
#git push -u github master

# push changes to dist-git master
#git push -u origin master

# sleep 10 seconds to let koji recognize the latest NVR
#sleep 10

# build package in koji
#fedpkg build

#-------
# CentOS
#-------

# remove stale docker-master.spec
#rm docker-master.spec

# copy latest docker.spec to docker-master.spec
#cp docker.spec docker-master.spec

# change package name for docker-master
#sed -i "s/Name: \%{repo}/Name: \%{repo}-master/" docker-master.spec

# docker-master Provides: docker
#sed -i "/Name: %{repo}-master/a Provides: %{repo} = %{version}-%{release}" \
#    docker-master.spec

# modify build tags for el7
#sed -i 's/selinux\"/selinux btrfs_noversion\"/' docker-master.spec

# build for el7
#rpmbuild --define 'dist .el7' -ba docker-master.spec --nocheck

# ckoji is a symlink to koji which uses my CentOS koji config
#~/bin/ckoji build virt7-el7 SRPMS/docker-master-*.el7.src.rpm
#~/bin/ckoji tag-pkg virt7-docker-master-testing $(ls SRPMS | sed -e "s/\.src.*//")
