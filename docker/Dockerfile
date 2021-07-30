FROM debian:buster

RUN apt-get update && apt-get install -y git m4 dosfstools kpartx wget parted curl unzip xz-utils sudo ostree uuid vim cpio
RUN cd /tmp && curl -L -O https://github.com/PocketNC/image-builder/releases/download/console-2021-07-23/bone-debian-10.9-console-2021-07-23-4gb.img.xz
RUN cd /tmp && git clone https://github.com/PocketNC/bbb-ostree-helper-scripts.git

ENTRYPOINT [ "/tmp/bbb-ostree-helper-scripts/ostree_prep_rootfs.sh" ]
