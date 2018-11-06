#!/bin/sh

. env.sh
. common.sh

bash builder.sh -p containernetworking-plugins -b master
bash builder.sh -p runc -b master
bash builder.sh -p podman -b master
bash builder.sh -p cri-o -b release-1.11
bash builder.sh -p cri-o -b release-1.12
bash builder.sh -p cri-tools -b release-1.11
bash builder.sh -p cri-tools -b release-1.12
send_to_openshift
