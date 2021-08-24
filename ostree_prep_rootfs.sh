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
if [ ! -n "${OSTREE_BRANCH}" ]; then
  echo "\$OSTREE_BRANCH must be defined"
  exit 1
fi
if [ ! -n "${OSTREE_SUBJECT}" ]; then
  echo "\$OSTREE_SUBJECT must be defined"
  exit 1
fi

cd /tmp

#mkdir /tmp/original
#cp -r ${BUILDDIR}/* /tmp/original

cd ${BUILDDIR}

# This is run at boot in /opt/scripts/boot/am335x_evm.sh, but errors due to read-only filesystem, doing it now while we can
sed -i -e 's:connmand -n:connmand -n --nodnsproxy:g' lib/systemd/system/connman.service || true

# /opt/scripts/tools/grow_partition.sh writes to /resizerootfs which is now a readonly location, so let's write to /var/resizerootfs
# We submitted a pull request to change these paths: (https://github.com/RobertCNelson/boot-scripts/pull/125)
# We'll want to take these lines out when those are merged:
if [ -f opt/scripts/tools/grow_partition.sh ]; then
  HAS_VAR=$(grep "/var/resizerootfs" opt/scripts/tools/grow_partition.sh)
  if [ -n "${HAS_VAR}" ]; then
    echo "Don't need to replace /resizerootfs with /var/resizerootfs in grow_partition.sh"
  else
    echo "Replacing /resizerootfs with /var/resizerootfs in grow_partition.sh"
    sed -i 's:/resizerootfs:/var/resizerootfs:g' opt/scripts/tools/grow_partition.sh
  fi
fi

if [ -f opt/scripts/boot/generic-startup.sh ]; then
  HAS_VAR=$(grep "/var/resizerootfs" opt/scripts/boot/generic-startup.sh)
  if [ -n "${HAS_VAR}" ]; then
    echo "Don't need to replace /resizerootfs with /var/resizerootfs in generic-startup.sh"
  else
    echo "Replacing /resizerootfs with /var/resizerootfs in generic-startup.sh"
    sed -i 's:/resizerootfs:/var/resizerootfs:g' opt/scripts/boot/generic-startup.sh
  fi
fi

mv opt usr
ln -s usr/opt opt

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
touch etc/machine-id
mv etc usr

mkdir -p usr/share/dpkg

mv var/lib/dpkg usr/share/dpkg/database
ln -sr usr/share/dpkg/database var/lib/dpkg

cat > usr/lib/tmpfiles.d/ostree.conf <<EOF
L /var/home - - - - ../sysroot/home
d /sysroot/home 0755 root root -
d /sysroot/root 0700 root root -
d /run/media 0755 root root -
L /var/lib/dpkg - - - - ../../usr/share/dpkg/database
EOF

mkdir -p sysroot
mv home /tmp/home
mv var /tmp/var
mkdir var
rm -rf {root,media} 
ln -s /sysroot/ostree ostree
ln -s /sysroot/home home
ln -s /sysroot/root root
ln -s /run/media media

ln -s ../lib boot/lib
ln -s $KERNEL_VERSION boot/dtbs/current
ln -s $KERNEL_VERSION lib/modules/current

ln -s vmlinuz-$KERNEL_VERSION boot/vmlinuz-current
ln -s initrd.img-$KERNEL_VERSION boot/initrd.img-current
ln -s System.map-$KERNEL_VERSION boot/System.map-current
ln -s config-$KERNEL_VERSION boot/config-current

cd /tmp 

# This is in here so ostree doesn't complain about the kernel 
# when doing "ostree admin deploy"
# TODO - develop a specialized Beaglebone ostree bootloader deployment
cd ${BUILDDIR}
cp boot/vmlinuz-$KERNEL_VERSION usr/lib/modules/$KERNEL_VERSION/vmlinuz
cp boot/initrd.img-$KERNEL_VERSION usr/lib/modules/$KERNEL_VERSION/initramfs.img
CHECKSUM=$(cat boot/vmlinuz-$KERNEL_VERSION boot/initrd.img-$KERNEL_VERSION | sha256sum | head -c 64)

sed -i 's/^uname_r=.*$/uname_r=current/' boot/uEnv.txt

mkdir -p usr/lib/ostree-boot

cat  > usr/lib/ostree-boot/setup.sh <<-__EOF__
#!/bin/bash

SYSROOT=\$1
DEPLOY=\$2
LOADER=\$3

echo "PWD: \$PWD"
echo "SYSROOT: \$SYSROOT"
echo "DEPLOY: \$DEPLOY"
echo "LOADER: \$LOADER"

cd \${SYSROOT}\${LOADER}

cp \${SYSROOT}\${DEPLOY}/boot/uEnv.txt uEnv.txt
sed -i "/^cmdline=/ s,\$, ostree=\${DEPLOY}," uEnv.txt

ln -s \${DEPLOY}/boot/vmlinuz-current
ln -s \${DEPLOY}/boot/initrd.img-current
ln -s \${DEPLOY}/boot/dtbs
ln -s \${DEPLOY}/boot/System.map-current
ln -s \${DEPLOY}/boot/config-current
ln -s \${DEPLOY}/boot/SOC.sh
ln -s \${DEPLOY}/boot/uboot
ln -s \${DEPLOY}/boot/lib

__EOF__
chmod +x usr/lib/ostree-boot/setup.sh

cd /tmp

REPO=/host/repo
if [ ! -d "$REPO" ]; then
  ostree --repo="$REPO" init --mode=archive-z2
fi
ostree commit --repo="$REPO" --branch="${OSTREE_BRANCH}" --subject="${OSTREE_SUBJECT}" --skip-if-unchanged --table-output "${BUILDDIR}"
ostree summary --repo="$REPO" --update

# Remove rootfs so ostree_client_setup.sh can replace them 
rm -r ${BUILDDIR}/*
