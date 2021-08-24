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

    # On a computer with git, docker, curl and unxz installed
    git clone https://github.com/PocketNC/bbb-ostree-helper-scripts
    cd bbb-ostree-helper-scripts

    # Pick an image to convert and download it
    curl -L -O https://rcn-ee.com/rootfs/bb.org/testing/2020-06-01/buster-iot/bone-debian-10.4-iot-armhf-2020-06-01-4gb.img.xz
    unxz bone-debian-10.4-iot-armhf-2020-06-01-4gb.img.xz

    # We'll pick another that we can update to
    curl -L -O https://rcn-ee.com/rootfs/bb.org/testing/2021-08-23/buster-iot/bone-debian-10.10-iot-armhf-2021-08-23-4gb.img.xz
    unxz bone-debian-10.10-iot-armhf-2021-08-23-4gb.img.xz

    # Either build the image using the commands in preview section or:
    docker pull pocketnc/build-bbb-ostree-image

    # specify that image on the docker run command, we'll start with the first
    docker run -ti --rm --privileged --env OSTREE_BRANCH="bb.org/testing/2020-06-01/buster-iot" --env OSTREE_SUBJECT="bone-debian-10.4-iot-armhf-2020-06-01-4gb" -v $PWD:/host pocketnc/build-bbb-ostree-image bone-debian-10.4-iot-armhf-2020-06-01-4gb.img

    # specify another image on the docker run command
    docker run -ti --rm --privileged --env OSTREE_BRANCH="bb.org/testing/2021-08-23/buster-iot" --env OSTREE_SUBJECT="bone-debian-10.10-iot-armhf-2021-08-23-4gb" -v $PWD:/host pocketnc/build-bbb-ostree-image bone-debian-10.10-iot-armhf-2021-08-23-4gb.img

Note, you may be prompted with questions from console-setup. With the `-ti` option specified on the `docker run` command, you should
be able to manually answer the questions, but I'm not sure the best way around this for a fully automated solution. If anyone knows
a work around, let me know! I've mostly been concerned with console images, which don't seem to have this issue.

bone-debian-10.4-iot-armhf-2020-06-01-4gb-ostree.img and bone-debian-10.10-iot-armhf-2021-08-23-4gb-ostree.img will be created
in the current directory. A repo directory will also be created if necessary in the current directory.
repo is an ostree archive repository that can be served with a static http server to be a remote. If repo already exists, a new commit will
be created in it.

If you'd like to simply download an ostree client image to get started, you can try this one:

    curl -L -O https://github.com/PocketNC/bbb-ostree-helper-scripts/releases/download/demo-files/bone-debian-10.4-iot-armhf-2020-06-01-4gb-ostree.img.xz

Flash the bone-debian-10.4-iot-armhf-2020-06-01-4gb-ostree.img file to a microSD card, then insert it into a Beaglebone and boot it up.
It should largely behave the same as the bone-debian-10.4-iot-armhf-2020-06-01-4gb.img file. The difference is the rootfs is configured
to be managed by ostree. There is a /sysroot directory that represents the real rootfs of the filesystem. The / directory is actually
a bind mount to a directory buried in /sysroot/ostree that represents the current deployment on the machine. /usr is mounted read-only
and many standard directories in / are symlinks into /usr. /home and /var remain mutable directories. /opt and /usr/local could feasibly
also be mutable directories by changing their symlinks to be under /var (i.e. /var/opt and /var/usrlocal). For now, they are part of
the commit that is checked into the ostree repository and are therefore read-only.

Below, we'll go through the steps on how to add a remote and update to atomically transition to a different deployment on a Beaglebone.

First, you'll need to sync your repo folder with a static webserver that your client Beaglebone can reach. Use something like
`rsync` or `aws s3 sync`.

On your client Beaglebone (the one you flashed with bone-debian-10.4-iot-armhf-2020-06-01-4gb-ostree.img), run the commands below.
http://pocketnc-ostree-test-repo.s3-website-us-east-1.amazonaws.com should be replaced with the URL of your static webserver that is serving the repo directory,
but it may work to leave it as is (it could go away at any time):

    # On Beaglebone client
    export REMOTE=debian
    export REMOTE_URL=http://pocketnc-ostree-test-repo.s3-website-us-east-1.com
    sudo ostree remote add --no-gpg-verify --no-sign-verify $REMOTE $REMOTE_URL
    sudo ostree pull $REMOTE bb.org/testing/2021-08-23/buster-iot
    sudo ostree admin deploy bb.org/testing/2021-08-23/buster-iot
    sudo reboot

When the Beaglebone reboots, it will be running debian 10.10 as if it had been flashed with bone-debian-10.10-iot-armhf-2020-06-01.img.
You can switch back with:

    # On Beaglebone client
    sudo ostree admin deploy bb.org/testing/2020-06-01/buster-iot
    sudo reboot

With a 4GB eMMC or microSD card there is ~900MB of free space with both images installed. OSTree is very space efficient and doesn't
duplicate files that are the same, so in images built almost 1 year apart there is only a ~400MB difference in the file data (when either image alone is about ~1.9GB decompressed and ~550MB compressed). 
The space savings is even better when updating more frequently due to fewer changes in the image. 

If space savings are important, data can be reclaimed as well:

    # On Beaglebone client
    sudo ostree admin undeploy 1
    sudo ostree refs --delete debian:bb.org/testing/2020-06-01/buster-iot
    sudo ostree admin cleanup

Many deployments could be maintained, even different types of images could be stored in the same repo (console, iot, lxqt, your own custom one, etc.). They could exist on the same microSD card and can easily be swapped between using `ostree admin deploy` and a reboot. 
Having many different kinds of deployments may require a larger microSD card. With a 32GB microSD card, for example, it would be no problem to have several different images installed.

Let's add in an LXQt image into the mix (run these on your host computer):

    # back on your computer in the bbb-ostree-helper-scripts directory
    curl -L -O https://rcn-ee.com/rootfs/bb.org/testing/2021-08-23/buster-lxqt/bone-debian-10.10-lxqt-armhf-2021-08-23-4gb.img.xz
    unxz bone-debian-10.10-lxqt-armhf-2021-08-23-4gb.img.xz
    docker run -ti --rm --privileged --env OSTREE_BRANCH="bb.org/testing/2021-08-23/buster-lxqt" --env OSTREE_SUBJECT="bone-debian-10.10-lxqt-armhf-2021-08-23-4gb" -v $PWD:/host pocketnc/build-bbb-ostree-image bone-debian-10.10-lxqt-armhf-2021-08-23-4gb.img

OSTree has something called static deltas that allow for fewer and more compressed requests to the server when syncing from a client:

    # on computer in the bbb-ostree-helper-scripts directory
    docker run -ti --entrypoint /bin/bash -v $PWD:/host pocketnc/build-bbb-ostree-image

    # In docker container's bash terminal
    cd /host/repo
    ostree static-delta generate --from=bb.org/testing/2021-08-23/buster-iot --to=bb.org/testing/2021-08-23/buster-lxqt
    ostree summary -u
    exit

Sync the ostree repository with your static webserver. Then you can efficiently update your Beaglebone client. If you cleaned out the
buster-iot image from 2020-06-01, then you even have space to pull the buster-lxqt image on a 4GB eMMC or microSD card. The space
difference is about ~150MB more than when using the regular lxqt image and you can freely switch between the iot and lxqt image and
have access to the same /home and /var.

    # On Beaglebone
    sudo ostree pull debian bb.org/testing/2021-08-23/buster-lxqt
    sudo ostree admin deploy bb.org/testing/2021-08-23/buster-lxqt

When using the lxqt image, there isn't much free space on the eMMC anyway. A microSD card is often a better option. When using a larger
microSD card, you can use the grow_partition.sh script like you would on a normal image to have access to all available storage:

    # On Beaglebone client
    sudo /opt/script/tools/grow_partition.sh
    sudo reboot
