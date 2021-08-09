#!/bin/bash

# Modified from
# https://salsa.debian.org/debian/ostree/-/blob/debian/master/debian/ostree-boot-examples/modified-deb-ostree-builder

if [ ! -n "${BUILDDIR}" ]; then
  echo "\$BUILDDIR must be defined"
  exit 1
fi
if [ ! -n "${KERNEL_VERSION}" ]; then
  echo "\$KERNEL_VERSION must be defined"
  exit 1
fi

cd /tmp

#mkdir /tmp/original
#cp -r ${BUILDDIR}/* /tmp/original

cd ${BUILDDIR}

# This is run at boot in /opt/scripts/boot/am335x_evm.sh, but errors due to read-only filesystem, doing it now while we can
sed -i -e 's:connmand -n:connmand -n --nodnsproxy:g' lib/systemd/system/connman.service || true

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
L /var/home - - - - ../sysroot/home
d /sysroot/home 0755 root root -
d /sysroot/root 0700 root root -
d /var/local 0755 root root -
d /run/media 0755 root root -
L /var/lib/dpkg - - - - ../../usr/share/dpkg/database
EOF

mkdir -p sysroot
mv home /tmp/home
rm -rf {root,media} usr/local
ln -s /sysroot/ostree ostree
ln -s /sysroot/home home
ln -s /sysroot/root root
ln -s /var/local usr/local
ln -s /run/media media

ln -s ../lib boot/lib
ln -s $KERNEL_VERSION boot/dtbs/current
ln -s $KERNEL_VERSION lib/modules/current
ln -s $KERNEL_VERSION var/lib/initramfs-tools/current

ln -s vmlinuz-$KERNEL_VERSION boot/vmlinuz-current
ln -s initrd.img-$KERNEL_VERSION boot/initrd.img-current
ln -s System.map-$KERNEL_VERSION boot/System.map-current
ln -s config-$KERNEL_VERSION boot/config-current

cd /tmp 
mkdir /tmp/initramfs
cd /tmp/initramfs
gunzip -c ${BUILDDIR}/boot/initrd.img-$KERNEL_VERSION | cpio -i

cp /host/switchroot.sh /tmp/initramfs/scripts/init-bottom
sed -i '/^\/scripts\/init-bottom\/udev/i /scripts/init-bottom/switchroot.sh' /tmp/initramfs/scripts/init-bottom/ORDER

find . | cpio -H newc -o | gzip -9 > ${BUILDDIR}/boot/initrd.img-$KERNEL_VERSION

# This is in here so ostree doesn't complain about the kernel 
# when doing "ostree admin deploy"
# TODO - develop a specialized Beaglebone ostree bootloader deployment
cd ${BUILDDIR}
cp boot/vmlinuz-$KERNEL_VERSION usr/lib/modules/$KERNEL_VERSION/vmlinuz
cp boot/initrd.img-$KERNEL_VERSION usr/lib/modules/$KERNEL_VERSION/initramfs.img
CHECKSUM=$(cat boot/vmlinuz-$KERNEL_VERSION boot/initrd.img-$KERNEL_VERSION | sha256sum | head -c 64)

# TODO - I'm using /ostree/boot here assuming this could be a symbolic link to the correct 
# /ostree/boot.1 or /ostree/boot.0. I don't quite understand how this is supposed to be done.
# If this deploy path can be known here at build time, then /boot could simply be a symlink
# to the ostree repository's /boot
#DEPLOY=/ostree/boot/${OSTREE_OS}/${CHECKSUM}/0
#REL_DEPLOY=ostree/boot/${OSTREE_OS}/${CHECKSUM}/0

sed -i 's/^uname_r=.*$/uname_r=current/' boot/uEnv.txt
#sed -i "/^cmdline=/ s,\$, ostree=$DEPLOY," boot/uEnv.txt

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
