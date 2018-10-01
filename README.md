Run this script like so:

For local build with no pushes:
`bash builder.sh -t scratch -p podman -k extras-rhel-7.5 -b master`

For local + brew build:
`bash builder.sh -t tagged -p podman -k extras-rhel-7.5 -b master`

Checkout env.sh for most env variables, common.sh for common build functions
and pkgs/default.sh for package specific info.
