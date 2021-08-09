#!/bin/bash

export INPUT_IMG=/host/$1
export IMG=/tmp/$(basename $1)
export OUTPUT_IMG=/host/$(basename $1 .img)-ostree.img

. /host/prepare_builddir.sh
. /host/install_dracut_and_ostree.sh
. /host/ostree_prep_rootfs.sh
. /host/create_ostree_rootfs.sh
. /host/cleanup.sh
