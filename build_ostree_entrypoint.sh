#!/bin/bash

export INPUT_IMG=/host/$1
export IMG=/tmp/$(basename $1)
export OUTPUT_IMG=/host/$(basename $1 .img)-ostree.img

. /host/prepare_builddir.sh
. /host/build_ostree.sh
. /host/cleanup.sh
