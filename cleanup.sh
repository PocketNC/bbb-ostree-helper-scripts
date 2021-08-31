#!/bin/bash

if [ ! -n "${BUILDDIR}" ]; then
  echo "\$BUILDDIR must be defined"
  exit 1
fi

if [ ! -n "${LOOP_DEV}" ]; then
  echo "\$LOOP_DEV must be defined"
  exit 1
fi

if [ ! -n "${IMG}" ]; then
  echo "\$IMG must be defined"
  exit 1
fi

if [ ! -n "${OUTPUT_IMG}" ]; then
  echo "\$OUTPUT_IMG must be defined"
  exit 1
fi

umount $BUILDDIR
sync
kpartx -d $LOOP_DEV
losetup -d $LOOP_DEV

echo "Copying ${IMG} to ${OUTPUT_IMG}..."
cp ${IMG} ${OUTPUT_IMG}
echo "Done"
#xz ${OUTPUT_IMG}
