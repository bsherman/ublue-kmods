# ublue-kmods

[![build-ublue](https://github.com/bsherman/ublue-kmods/actions/workflows/build.yml/badge.svg)](https://github.com/bsherman/ublue-kmods/actions/workflows/build.yml)

A layer to store extra driver RPMs on an image for consumption by other images.

Included:
- wl (broadcom legacy wireless) driver
- xone (xbox one wired/rf usb) driver
- xpadneo (xbox one bluetooth) driver

*nvidia* variants are no longer built here. 

There are two alternatives:
1. my upstream, [ublue-os/nvidia](https://github.com/ublue-os/nvidia) is pretty much stock Silverblue/Kinoite/etc plus nvidia and some nice basic improvements
2. my custom images also include nvidia variants, [bsherman/ublue-custom](https://github.com/bsherman/ublue-custom)


## Acknowledgements

Thanks to Jorge Castro and [team ublue os](https://github.com/ublue-os) for their efforts to get people started with ostree native containers.
