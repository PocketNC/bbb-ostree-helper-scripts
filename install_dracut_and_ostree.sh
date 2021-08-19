#!/bin/bash

echo "Installing dracut and ostree..."

# From https://github.com/beagleboard/image-builder/blob/master/scripts/chroot.sh
chroot_mount () {
  if [ "$(mount | grep ${BUILDDIR}/sys | awk '{print $3}')" != "${BUILDDIR}/sys" ] ; then
    sudo mount -t sysfs sysfs "${BUILDDIR}/sys"
  fi

  if [ "$(mount | grep ${BUILDDIR}/proc | awk '{print $3}')" != "${BUILDDIR}/proc" ] ; then
    sudo mount -t proc proc "${BUILDDIR}/proc"
  fi

  if [ ! -d "${BUILDDIR}/dev/pts" ] ; then
    sudo mkdir -p ${BUILDDIR}/dev/pts || true
  fi

  if [ "$(mount | grep ${BUILDDIR}/dev/pts | awk '{print $3}')" != "${BUILDDIR}/dev/pts" ] ; then
    sudo mount -t devpts devpts "${BUILDDIR}/dev/pts"
  fi
}

chroot_umount () {
  if [ "$(mount | grep ${BUILDDIR}/dev/pts | awk '{print $3}')" = "${BUILDDIR}/dev/pts" ] ; then
    echo "Log: umount: [${BUILDDIR}/dev/pts]"
    sync
    sudo umount -fl "${BUILDDIR}/dev/pts"

    if [ "$(mount | grep ${BUILDDIR}/dev/pts | awk '{print $3}')" = "${BUILDDIR}/dev/pts" ] ; then
      echo "Log: ERROR: umount [${BUILDDIR}/dev/pts] failed..."
      exit 1
    fi
  fi

  if [ "$(mount | grep ${BUILDDIR}/proc | awk '{print $3}')" = "${BUILDDIR}/proc" ] ; then
    echo "Log: umount: [${BUILDDIR}/proc]"
    sync
    sudo umount -fl "${BUILDDIR}/proc"

    if [ "$(mount | grep ${BUILDDIR}/proc | awk '{print $3}')" = "${BUILDDIR}/proc" ] ; then
      echo "Log: ERROR: umount [${BUILDDIR}/proc] failed..."
      exit 1
    fi
  fi

  if [ "$(mount | grep ${BUILDDIR}/sys | awk '{print $3}')" = "${BUILDDIR}/sys" ] ; then
    echo "Log: umount: [${BUILDDIR}/sys]"
    sync
    sudo umount -fl "${BUILDDIR}/sys"

    if [ "$(mount | grep ${BUILDDIR}/sys | awk '{print $3}')" = "${BUILDDIR}/sys" ] ; then
      echo "Log: ERROR: umount [${BUILDDIR}/sys] failed..."
      exit 1
    fi
  fi

  if [ "$(mount | grep ${BUILDDIR}/run | awk '{print $3}')" = "${BUILDDIR}/run" ] ; then
    echo "Log: umount: [${BUILDDIR}/run]"
    sync
    sudo umount -fl "${BUILDDIR}/run"

    if [ "$(mount | grep ${BUILDDIR}/run | awk '{print $3}')" = "${BUILDDIR}/run" ] ; then
      echo "Log: ERROR: umount [${BUILDDIR}/run] failed..."
      exit 1
    fi
  fi
}

cat > "${BUILDDIR}/chroot_script.sh" <<-__EOF__
#sed -i "s/^#deb-src/deb-src/" /etc/apt/sources.list
apt-get update
apt-get install -y dracut git
#apt-get install -y build-essential
#apt-get build-dep -y ostree

# install ostree and it's dependencies
# CAREFUL - we're building from source
# so dependencies may have changed since
# current debian version of ostree
apt-get install -y ostree

# remove ostree so only dependencies are left
apt-get purge -y ostree libostree-1-1

cd /tmp

wget https://github.com/PocketNC/ostree/releases/download/test4/ostree.tar.gz
tar xzf ostree.tar.gz
cd ostree_install
cp -r * /

# TODO - build this before hand and simply install binaries
# (don't install all the build-deps above either)
# Can't seem to get this to work with make install DESTDIR=/tmp/ostree_install
# Not sure what I'm doing wrong, but ostree complains about missing
# libraries
#git clone https://github.com/PocketNC/ostree.git
#cd ostree
#git submodule update --init
#env NOCONFIGURE=1 ./autogen.sh
#./configure --with-dracut --prefix /usr
#make
#make install

#mkdir -p /tmp/ostree_install
#make install DESTDIR=/tmp/ostree_install
#cd ..
#rm -rf ostree

#tar czf ostree.tar.gz ostree_install

dracut --force --add ostree /boot/initrd.img-$KERNEL_VERSION $KERNEL_VERSION

rm -rf /usr/etc

rm /usr/bin/qemu-arm-static
rm /etc/resolv.conf
ln -s  /run/connman/resolv.conf /etc/resolv.conf

apt-get clean

rm /chroot_script.sh

__EOF__


QEMU=$(which qemu-arm-static)

if [ ! -n "${QEMU}" ]; then
  echo "qemu-user-static package must be installed"
fi

cp $QEMU ${BUILDDIR}/usr/bin
cp --remove-destination /etc/resolv.conf ${BUILDDIR}/etc/resolv.conf
chroot_mount
chroot ${BUILDDIR} qemu-arm-static /bin/bash -e /chroot_script.sh
chroot_umount

#cp ${BUILDDIR}/tmp/ostree.tar.gz /host
