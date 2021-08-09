#!/bin/bash

# Modified from
# https://github.com/dbnicholson/deb-ostree-builder/blob/simple-builder/create-deployment

#OSTREE_SYSROOT=$(mktemp -d -p /var/tmp ostree-deploy.XXXXXXXXXX)
# Make sure ostree_prep_rootfs.sh runs first so /mnt/ostree_rootfs is setup
OSTREE_SYSROOT=${BUILDDIR}
# TODO add a remote URL
#OSTREE_URL=https://www.example.com
OSTREE_BRANCH_DEPLOY=pocketnc/bbb/console
OSTREE_REPODIR=/tmp/repo
OSTREE_OS=debian
REPOPATH=${OSTREE_SYSROOT}/ostree/repo
BOOT=${OSTREE_SYSROOT}/boot

DEPLOY=/ostree/boot.1/${OSTREE_OS}/${CHECKSUM}/0
REL_DEPLOY=ostree/boot.1/${OSTREE_OS}/${CHECKSUM}/0

echo "Creating OSTree client rootfs in..."
echo $OSTREE_SYSROOT

ostree admin init-fs "${OSTREE_SYSROOT}"
ostree admin --sysroot="${OSTREE_SYSROOT}" os-init ${OSTREE_OS}
#ostree --repo="${REPOPATH}" remote add ${OSTREE_OS} ${OSTREE_URL} ${OSTREE_BRANCH_DEPLOY}
#ostree --repo="${REPOPATH}" pull ${OSTREE_OS}:${OSTREE_BRANCH_DEPLOY}
ostree --repo="${REPOPATH}" pull-local --disable-fsync --remote=${OSTREE_OS} ${OSTREE_REPODIR} ${OSTREE_BRANCH_DEPLOY}
#ostree --repo="${REPOPATH}" config set sysroot.bootloader none

uuid=$(uuid)
kargs=(--karg=root=UUID=${uuid} --karg=rw --karg=splash --karg=plymouth.ignore-serial-consoles --karg=quiet)
ostree admin --sysroot="${OSTREE_SYSROOT}" deploy --os=${OSTREE_OS} "${kargs[@]}" ${OSTREE_OS}:${OSTREE_BRANCH_DEPLOY}

# TODO - I believe this should eventually be done by ostree admin deploy
cd $BUILDDIR
cp $REL_DEPLOY/boot/uEnv.txt boot/loader.1
cd boot/loader.1
sed -i "/^cmdline=/ s,\$, ostree=$DEPLOY," uEnv.txt
ln -s ${DEPLOY}/boot/vmlinuz-current
ln -s ${DEPLOY}/boot/initrd.img-current
ln -s ${DEPLOY}/boot/dtbs
ln -s ${DEPLOY}/boot/System.map-current
ln -s ${DEPLOY}/boot/config-current
ln -s ${DEPLOY}/boot/SOC.sh
ln -s ${DEPLOY}/boot/uboot
ln -s ${DEPLOY}/boot/lib

# Once these are setup, they shouldn't need to change
cd $BUILDDIR/boot
ln -s loader/uEnv.txt
ln -s loader/vmlinuz-current
ln -s loader/initrd.img-current
ln -s loader/dtbs
ln -s loader/System.map-current
ln -s loader/config-current
ln -s loader/SOC.sh
ln -s loader/uboot

# So U-Boot can find firmware
cd $BUILDDIR
ln -s boot/loader/lib


cd /tmp

mv /tmp/home/* ${BUILDDIR}/home
#mv /tmp/etc ${BUILDDIR}

#mkdir /tmp/ostree_rootfs
#cp -r ${BUILDDIR}/* /tmp/ostree_rootfs
