#!/bin/sh

# This demonstration script is an implementation in shell
# similar to ostree-prepare-root.c.  For a bit more information,
# see adapting-existing.md.

## the ostree boot parameter is avaialbe during the init
env | grep ostree
# ostree=/ostree/boot.1/.../.../0
## bind mount the ostree deployment to prepare it for move
mount --bind $rootmnt$ostree $rootmnt$ostree
## bind mount read-only /usr
mount --bind $rootmnt$ostree/usr $rootmnt$ostree/usr
mount --bind -o remount,ro $rootmnt$ostree/usr $rootmnt$ostree/usr
## bind mount the physical root
mount --bind $rootmnt $rootmnt$ostree/sysroot
## bind mount the var directory which is preserved between deployments
mount --bind $rootmnt/ostree/deploy/debian/var $rootmnt$ostree/var
## make sure target directories are present within var
cd $rootmnt$ostree/var
mkdir -p roothome mnt opt home
cd -
## move the deployment to the sysroot
mount --move $rootmnt$ostree $rootmnt
## after these the init system should start the switch root process
