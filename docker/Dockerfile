FROM debian:buster

RUN apt-get update && apt-get install -y git m4 dosfstools kpartx wget parted curl unzip xz-utils sudo uuid vim cpio qemu-user-static

COPY build-ostree.sh /tmp/build-ostree.sh
RUN /tmp/build-ostree.sh

RUN apt-get install -y ostree
RUN apt-get purge -y ostree libostree-1-1

ENTRYPOINT [ "/host/entrypoint.sh" ]
