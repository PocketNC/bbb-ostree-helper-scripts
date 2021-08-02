# bbb-ostree-helper-scripts

Some scripts that help turn a BBB image into an image with a rootfs that is managed by OSTree.

# docker folder

Docker container with dependencies for converting a Beaglebone image into
an image that leverages OSTree to manage full system updates. 
Work in progress...

# How to build image

    git clone https://github.com/PocketNC/bbb-ostree-helper-scripts
    cd bbb-ostree-helper-scripts/docker
    docker build . --tag pocketnc/build-bbb-ostree-image
    docker push pocketnc/build-bbb-ostree-image

# How to use image

    git clone https://github.com/PocketNC/bbb-ostree-helper-scripts
    cd bbb-ostree-helper-scripts

    # pick an image to convert and download it
    curl -L -O https://rcn-ee.com/rootfs/bb.org/testing/2020-05-18/buster-console/bone-debian-10.4-console-armhf-2020-05-18-1gb.img.xz

    # Either build the image using the commands above or:
    docker pull pocketnc/build-bbb-ostree-image

    # specify that image on the docker run command
    docker run --rm --privileged -v $PWD:/host pocketnc/build-bbb-ostree-image bone-debian-10.4-console-armhf-2020-05-18-1gb.img.xz
