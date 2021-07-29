# build-bbb-ostree-console

Docker container for converting a BBB console image into an image that
leverages OSTree to manage full system updates. Work in progress...

    docker build . --tag pocketnc/build-bbb-ostree-console
    docker push pocketnc/build-bbb-ostree-console
