#!/bin/bash

export INPUT_IMG=/host/$1
export IMG=/tmp/$(basename $INPUT_IMG)
export OUTPUT_IMG=/host/$(basename $INPUT_IMG .img)-ostree.img

. /host/prepare_builddir.sh
. /host/install_dracut_and_ostree.sh
. /host/ostree_prep_rootfs.sh
. /host/create_ostree_rootfs.sh
. /host/cleanup.sh
