# ublue-kmods

[![build-ublue](https://github.com/bsherman/ublue-kmods/actions/workflows/build.yml/badge.svg)](https://github.com/bsherman/ublue-kmods/actions/workflows/build.yml)

A layer to store extra driver RPMs on an image for consumption by other images.

Included:
- xone (xbox one wired/rf usb) driver
- xpadneo (xbox one bluetooth) driver

Full usable images are no longer built here.

There are two alternatives:
1. my upstream, [ublue-os/main](https://github.com/ublue-os/main) and [ublue-os/nvidia](https://github.com/ublue-os/nvidia) are pretty much stock Silverblue/Kinoite/etc plus some nice quality of life improvements, plus the latter includes nvidia drivers.
2. my custom images build on those upstreams and add the kmod driver RPMs built in this repo, [bsherman/ublue-custom](https://github.com/bsherman/ublue-custom)


## Acknowledgements

Thanks to Jorge Castro and [team ublue os](https://github.com/ublue-os) for their efforts to get people started with ostree native containers.
