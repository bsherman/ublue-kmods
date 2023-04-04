#!/bin/sh

set -ouex pipefail

wget https://negativo17.org/repos/fedora-steam.repo -O /etc/yum.repos.d/fedora-steam.repo

sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-{cisco-openh264,modular,updates-modular}.repo

# be careful about extra-enabling repos
grep "enabled=1" /etc/yum.repos.d/rpmfusion*.repo
#RPMFUSION_ENABLED="$(grep enabled=1 /etc/yum.repos.d/rpmfusion-*.repo > /dev/null; echo $?)"
#if [[ "$RPMFUSION_ENABLED" == "1" ]]; then \
#    sed -i '0,/enabled=0/{s/enabled=0/enabled=1/}' /etc/yum.repos.d/rpmfusion-{,non}free{,-updates}.repo; \
#fi

KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
# install stuff
rpm-ostree install --idempotent \
  /tmp/akmods/wl/kmod-wl-${KERNEL_VERSION}-*.rpm \
  /tmp/akmods/xone/kmod-xone-${KERNEL_VERSION}-*.rpm \
  /tmp/akmods/xpadneo/kmod-xpadneo-${KERNEL_VERSION}-*.rpm \
  /tmp/akmods-custom-key/rpmbuild/RPMS/noarch/akmods-custom-key-*.rpm \

# cleanup stuff
rm -rf \
  /etc/yum.repos.d/fedora-steam.repo \
  /tmp/* \
  /var/*
ostree container commit
mkdir -p /tmp /var/tmp
chmod 1777 /tmp /var/tmp
