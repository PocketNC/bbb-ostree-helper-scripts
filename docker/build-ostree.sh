#!/bin/bash

echo "deb-src https://deb.debian.org/debian buster main non-free contrib" >> /etc/apt/sources.list
apt-get update

apt-get -y install build-essential 
apt-get -y build-dep ostree

cd /tmp
git clone https://github.com/pocketnc/ostree

cd ostree
git submodule update --init
env NOCONFIGURE=1 ./autogen.sh
./configure --with-dracut

make
make install
