#!/bin/bash

echo "deb-src https://deb.debian.org/debian bookworm main contrib non-free non-free-firmware" >> /etc/apt/sources.list
apt-get update -y

apt-get -y install build-essential 
apt-get -y build-dep ostree

cd /tmp
git clone --single-branch --branch bookworm https://github.com/pocketnc/ostree

cd ostree
git submodule update --init
env NOCONFIGURE=1 ./autogen.sh
./configure --with-dracut

make
make install
