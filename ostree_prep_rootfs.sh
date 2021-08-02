#!/bin/bash

# Modified from
# https://salsa.debian.org/debian/ostree/-/blob/debian/master/debian/ostree-boot-examples/modified-deb-ostree-builder

cd /tmp

IMG_XZ=/tmp/$(basename $1)
IMG=/tmp/$(basename $1 .xz)
OUTPUT_IMG=/host/$(basename $1 .img.xz)-ostree.img

cp /host/$1 $IMG_XZ

unxz $IMG_XZ

LOOP_DEV=$(losetup -f)
LOOP_NUM=$(echo ${LOOP_DEV} | awk -F'/' '{print $3}')
losetup $LOOP_DEV $IMG
kpartx -av $LOOP_DEV

BUILDDIR=/mnt/ostree_rootfs
mkdir -p $BUILDDIR

mount /dev/mapper/${LOOP_NUM}p1 $BUILDDIR

cd ${BUILDDIR}

mv bin/* usr/bin
rm -r bin
ln -s usr/bin bin

mv sbin/* usr/sbin/
rm -r sbin
ln -s usr/sbin sbin

mkdir -p usr/lib/arm-linux-gnueabihf
mkdir -p usr/lib/systemd
mv lib/arm-linux-gnueabihf/* usr/lib/arm-linux-gnueabihf/
mv lib/systemd/* usr/lib/systemd/
rm -r lib/arm-linux-gnueabihf
rm -r lib/systemd
mv lib/* usr/lib/
rm -r lib
ln -s usr/lib lib

rm -rf dev
mkdir dev

sed -i -e 's|DHOME=/home|DHOME=/sysroot/home|g' etc/adduser.conf
sed -i -e 's|DHOME=/home|DHOME=/sysroot/home|g' etc/default/useradd
mv etc usr

mkdir -p usr/share/dpkg

mv var/lib/dpkg usr/share/dpkg/database
ln -sr usr/share/dpkg/database var/lib/dpkg

cat > usr/lib/tmpfiles.d/ostree.conf <<EOF
d /sysroot/home 0755 root root -
d /sysroot/root 0700 root root -
d /var/local 0755 root root -
d /run/media 0755 root root -
L /var/lib/dpkg - - - - ../../usr/share/dpkg/database
EOF

mkdir -p sysroot
rm -rf {home,root,media} usr/local
ln -s /sysroot/ostree ostree
ln -s /sysroot/home home
ln -s /sysroot/root root
ln -s /var/local usr/local
ln -s /run/media media

# TODO - be smarter about kernel version, but for now this is just in here
# so ostree doesn't complain about the kernel when doing "ostree admin deploy"
UNAME_R=$(grep "uname_r=" boot/uEnv.txt)
KERNEL_VERSION=$(echo "${UNAME_R/uname_r=}")
cp boot/vmlinuz-$KERNEL_VERSION usr/lib/modules/$KERNEL_VERSION/vmlinuz
cp boot/initrd.img-$KERNEL_VERSION usr/lib/modules/$KERNEL_VERSION/initramfs.img

cd /tmp 
mkdir /tmp/initramfs
cd /tmp/initramfs
gunzip -c ${BUILDDIR}/boot/initrd.img-$KERNEL_VERSION | cpio -i

cp /host/switchroot.sh /tmp/initramfs/scripts/init-bottom
sed -i '/^\/scripts\/init-bottom\/udev/i /scripts/init-bottom/switchroot.sh' /tmp/initramfs/scripts/init-bottom/ORDER

find . | cpio -H newc -o | gzip -9 > ${BUILDDIR}/boot/initrd.img-$KERNEL_VERSION

cd /tmp

mkdir repo
REPO=/tmp/repo
# TODO - eventually we won't be creating the repo every time
# and simply adding a commit to it
ostree --repo="$REPO" init --mode=archive-z2
ostree commit --repo="$REPO" --branch="pocketnc/bbb/console" --subject="Build bbb console" --skip-if-unchanged --table-output ${BUILDDIR}
ostree summary --repo="$REPO" --update

# Remove rootfs so ostree_client_setup.sh can replace them 
rm -r ${BUILDDIR}/*

# Modified from
# https://github.com/dbnicholson/deb-ostree-builder/blob/simple-builder/create-deployment

#OSTREE_SYSROOT=$(mktemp -d -p /var/tmp ostree-deploy.XXXXXXXXXX)
# Make sure ostree_prep_rootfs.sh runs first so /mnt/ostree_rootfs is setup
OSTREE_SYSROOT=${BUILDDIR}
OSTREE_OS=debian
# TODO add a remote URL
#OSTREE_URL=https://www.example.com
OSTREE_BRANCH_DEPLOY=pocketnc/bbb/console
OSTREE_REPODIR=/tmp/repo
REPOPATH=${OSTREE_SYSROOT}/ostree/repo
BOOT=${OSTREE_SYSROOT}/boot

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

# TODO - * is used below, but is assuming only one folder/file will match because the repo only has a single commit/deployment
# Eventually we won't be able to make that assumption, but taking a shortcut for now. How do we figure out what deployment
# is active?

cd $BUILDDIR/boot
ln -s loader/uEnv.txt
ln -s loader/vmlinuz-$KERNEL_VERSION
ln -s loader/initrd.img-$KERNEL_VERSION
ln -s loader/dtbs
ln -s loader/System.map-$KERNEL_VERSION
ln -s loader/config-$KERNEL_VERSION
ln -s loader/SOC.sh
ln -s loader/uboot

cd $BUILDDIR/boot/loader
cp ../../ostree/deploy/debian/deploy/*/boot/uEnv.txt .

# Add ostree= argument to kernel cmdline arguments
DEPLOY=$(echo ../../ostree/deploy/debian/deploy/*/ | sed 's,/$,,')
ABS_DEPLOY=$(echo $DEPLOY | sed 's,../../,/,')
REL_DEPLOY=$(echo $DEPLOY | sed 's,../../,,')
sed -i "/^cmdline=/ s,\$, ostree=$ABS_DEPLOY," uEnv.txt

ln -s $DEPLOY/boot/vmlinuz-$KERNEL_VERSION
ln -s $DEPLOY/boot/initrd.img-$KERNEL_VERSION
ln -s $DEPLOY/boot/dtbs
ln -s $DEPLOY/boot/System.map-$KERNEL_VERSION
ln -s $DEPLOY/boot/config-$KERNEL_VERSION
ln -s $DEPLOY/boot/SOC.sh
ln -s $DEPLOY/boot/uboot

# So U-Boot can find firmware
cd ${BUILDDIR}
ln -s $REL_DEPLOY/lib
ln -s $REL_DEPLOY/usr

cd /tmp

umount $BUILDDIR
sync
kpartx -d $LOOP_DEV
losetup -d $LOOP_DEV

cp ${IMG} ${OUTPUT_IMG}
#xz ${OUTPUT_IMG}
