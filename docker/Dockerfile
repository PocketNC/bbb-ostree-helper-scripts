FROM debian:buster

RUN apt-get update && apt-get install -y git m4 dosfstools kpartx wget parted curl unzip xz-utils sudo ostree uuid vim cpio qemu-user-static

ENTRYPOINT [ "/host/entrypoint.sh" ]
