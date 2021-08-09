#!/bin/bash

if [ ! -n "${INPUT_IMG}" ]; then
  echo "\$INPUT_IMG must be defined"
  exit 1
fi
if [ ! -n "${IMG}" ]; then
  echo "\$IMG must be defined"
  exit 1
fi

cp $INPUT_IMG $IMG

export LOOP_DEV=$(losetup -f)
export LOOP_NUM=$(echo ${LOOP_DEV} | awk -F'/' '{print $3}')
losetup $LOOP_DEV $IMG
kpartx -av $LOOP_DEV

export BUILDDIR=/mnt/ostree_rootfs
mkdir -p $BUILDDIR

mount /dev/mapper/${LOOP_NUM}p1 $BUILDDIR

export UNAME_R=$(grep "uname_r=" ${BUILDDIR}/boot/uEnv.txt)
export KERNEL_VERSION=$(echo "${UNAME_R/uname_r=}")

