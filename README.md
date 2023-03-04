# ublue-kmods

[![build-ublue](https://github.com/bsherman/ublue-kmods/actions/workflows/build.yml/badge.svg)](https://github.com/bsherman/ublue-kmods/actions/workflows/build.yml)

A layer to build extra drivers into an image for consumption by other images, based on [ublue-os/main](https://github.com/ublue-os/main) images.

Included:
- xone driver
- xpadneo driver
- ... plus all the goodies from *ublue-os/main* ...

*nvidia* variants include packages from [ublue-os/nvidia](https://github.com/ublue-os/nvidia), primarily:
- nvidia drivers
- nvidia container runtime


If used directly, this image is mostly vanilla Fedora Silverblue/Kinoite/Vauxite except as described above.

#### NOTE: this project is not formally affiliated with [ublue-os](https://github.com/ublue-os/) and is not supported by their team.


## Setup

1. Rebase onto the image

   Any system running `rpm-ostree` should be able to rebase onto one of the images built in this project:

       rpm-ostree rebase ostree-unverified-registry:ghcr.io/bsherman/silverblue-kmods:latest
       rpm-ostree rebase ostree-unverified-registry:ghcr.io/bsherman/silverblue-nvidia-kmods:latest
       rpm-ostree rebase ostree-unverified-registry:ghcr.io/bsherman/kinoite-kmods:latest
       rpm-ostree rebase ostree-unverified-registry:ghcr.io/bsherman/kinoite-nvidia-kmods:latest
       rpm-ostree rebase ostree-unverified-registry:ghcr.io/bsherman/vauxite-kmods:latest
       rpm-ostree rebase ostree-unverified-registry:ghcr.io/bsherman/vauxite-nvidia-kmods:latest

   And then reboot.

2. Set kargs after rebasing

```
rpm-ostree kargs \
    --append=rd.driver.blacklist=nouveau \
    --append=modprobe.blacklist=nouveau \
    --append=nvidia-drm.modeset=1
```
   And then reboot one more time!

3. Enable Secure Boot support

    [Secure Boot](https://rpmfusion.org/Howto/Secure%20Boot) support for the kernel modules can be enabled by enrolling the signing key:

```
# note there are two different keys, one for nvidia by ublue-os, one for custom kmods in this project
sudo mokutil --import /etc/pki/akmods/certs/akmods-custom.der
# akmods-nvidia.der only exists on nvidia images
sudo mokutil --import /etc/pki/akmods/certs/akmods-nvidia.der
```


## Rolling back

   To rollback to a specific date, use a date tag:

       rpm-ostree rebase ostree-unverified-registry:ghcr.io/bsherman/silverblue-kmods:20230302
       rpm-ostree rebase ostree-unverified-registry:ghcr.io/bsherman/silverblue-nvidia-kmods:20230302
       rpm-ostree rebase ostree-unverified-registry:ghcr.io/bsherman/kinoite-kmods:20230302
       rpm-ostree rebase ostree-unverified-registry:ghcr.io/bsherman/kinoite-nvidia-kmods:20230302
       rpm-ostree rebase ostree-unverified-registry:ghcr.io/bsherman/vauxite-kmods:20230302
       rpm-ostree rebase ostree-unverified-registry:ghcr.io/bsherman/vauxite-nvidia-kmods:20230302

 ## Verification

These images are signed with sigstore's [cosign](https://docs.sigstore.dev/cosign/overview/). You can verify the signature by downloading the `cosign.pub` key from this repo and running the appropriate command:

    cosign verify --key cosign.pub ghcr.io/bsherman/silverblue-kmods
    cosign verify --key cosign.pub ghcr.io/bsherman/silverblue-nvidia-kmods
    cosign verify --key cosign.pub ghcr.io/bsherman/kinoite-kmods
    cosign verify --key cosign.pub ghcr.io/bsherman/kinoite-nvidia-kmods
    cosign verify --key cosign.pub ghcr.io/bsherman/vauxite-kmods
    cosign verify --key cosign.pub ghcr.io/bsherman/vauxite-nvidia-kmods

## Other Details

Read more details about [building locally](https://github.com/ublue-os/nvidia#building-locally) and [using nvidia in containers](https://github.com/ublue-os/nvidia#using-nvidia-gpus-in-containers) in the [ublue-os/nvidia repo](https://github.com/ublue-os/nvidia).


## Acknowledgements

Thanks to Jorge Castro and [team ublue os](https://github.com/ublue-os) for their efforts to get people started with ostree native containers.
