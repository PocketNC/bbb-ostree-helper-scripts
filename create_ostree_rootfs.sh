#!/bin/bash

# Modified from
# https://github.com/dbnicholson/deb-ostree-builder/blob/simple-builder/create-deployment

#OSTREE_SYSROOT=$(mktemp -d -p /var/tmp ostree-deploy.XXXXXXXXXX)
# Make sure ostree_prep_rootfs.sh runs first so /mnt/ostree_rootfs is setup
OSTREE_SYSROOT=${BUILDDIR}
# TODO add a remote URL
#OSTREE_URL=https://www.example.com
OSTREE_BRANCH_DEPLOY=${OSTREE_BRANCH}
OSTREE_REPODIR=/host/repo
OSTREE_OS=${OSTREE_OS:=debian}
REPOPATH=${OSTREE_SYSROOT}/ostree/repo
BOOT=${OSTREE_SYSROOT}/boot

DEPLOY=/ostree/boot.1/${OSTREE_OS}/${CHECKSUM}/0
REL_DEPLOY=ostree/boot.1/${OSTREE_OS}/${CHECKSUM}/0

echo "Creating OSTree client rootfs in..."
echo $OSTREE_SYSROOT

# Set up a fake loader directory with a uEnv.txt file
# so ostree treats the sysroot as a U-Boot bootloader.
# We explicitly set it to be a uboot bootloader, but
# it complains if there is no uEnv.txt file.
mkdir -p $BUILDDIR/boot/loader.0
cd $BUILDDIR/boot
ln -s loader.0 loader
touch $BUILDDIR/boot/loader/uEnv.txt

ostree admin init-fs "${OSTREE_SYSROOT}"
ostree admin --sysroot="${OSTREE_SYSROOT}" os-init ${OSTREE_OS}
#ostree --repo="${REPOPATH}" remote add ${OSTREE_OS} ${OSTREE_URL} ${OSTREE_BRANCH_DEPLOY}
#ostree --repo="${REPOPATH}" pull ${OSTREE_OS}:${OSTREE_BRANCH_DEPLOY}
ostree --repo="${REPOPATH}" pull-local --disable-fsync --remote=${OSTREE_OS} ${OSTREE_REPODIR} ${OSTREE_BRANCH_DEPLOY}
ostree --repo="${REPOPATH}" config set sysroot.bootloader uboot

uuid=$(uuid)
kargs=(--karg=root=UUID=${uuid} --karg=rw --karg=splash --karg=plymouth.ignore-serial-consoles --karg=quiet)
ostree admin --sysroot="${OSTREE_SYSROOT}" deploy --os=${OSTREE_OS} "${kargs[@]}" ${OSTREE_BRANCH_DEPLOY}

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
rm -r /tmp/home
mv /tmp/var/* ${BUILDDIR}/ostree/deploy/${OSTREE_OS}/var
rm -r /tmp/var
mkdir ${BUILDDIR}/var
mkdir -p ${BUILDDIR} /run/media/usb0
mkdir -p ${BUILDDIR} /run/media/usb1
mkdir -p ${BUILDDIR} /run/media/usb2
mkdir -p ${BUILDDIR} /run/media/usb3
mkdir -p ${BUILDDIR} /run/media/usb4
mkdir -p ${BUILDDIR} /run/media/usb5
mkdir -p ${BUILDDIR} /run/media/usb6
mkdir -p ${BUILDDIR} /run/media/usb7
#mv /tmp/etc ${BUILDDIR}

#mkdir /tmp/ostree_rootfs
#cp -r ${BUILDDIR}/* /tmp/ostree_rootfs
