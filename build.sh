sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-{cisco-openh264,modular,updates-modular}.repo

sed -i '0,/enabled=0/{s/enabled=0/enabled=1/}' /etc/yum.repos.d/rpmfusion-{,non}free{,-updates}.repo

wget https://negativo17.org/repos/fedora-steam.repo -O /etc/yum.repos.d/fedora-steam.repo && \
    rpm-ostree install \
        akmods \
        mock \
        akmod-wl \
        akmod-xone \
        akmod-xpadneo

# alternatives cannot create symlinks on its own during a container build
if [[ ! -e /etc/alternatives/ld ]]; then \
    ln -s /usr/bin/ld.bfd /etc/alternatives/ld && ln -s /etc/alternatives/ld /usr/bin/ld; fi


if [[ ! -s "/tmp/certs/private_key.priv" ]]; then
    echo "WARNING: Using test signing key. Run './generate-akmods-key' for production builds."
    cp /tmp/certs/private_key.priv{.test,}
    cp /tmp/certs/public_key.der{.test,}
fi

install -Dm644 /tmp/certs/public_key.der   /etc/pki/akmods/certs/public_key.der
install -Dm644 /tmp/certs/private_key.priv /etc/pki/akmods/private/private_key.priv

# protect against incorrect permissions in tmp dirs with break akmods builds
chmod 1777 /tmp /var/tmp

# Either successfully build and install wl kernel modules, or fail early with debug output
KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')" \
    && akmods --force --kernels "${KERNEL_VERSION}" --kmod wl \
    && modinfo /usr/lib/modules/${KERNEL_VERSION}/extra/wl/wl.ko.xz > /dev/null \
    || (cat /var/cache/akmods/wl/*-for-${KERNEL_VERSION}.failed.log && exit 1)

# Either successfully build and install xone kernel modules, or fail early with debug output
KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')" \
    && akmods --force --kernels "${KERNEL_VERSION}" --kmod xone \
    && modinfo /usr/lib/modules/${KERNEL_VERSION}/extra/xone/xone-{dongle,gip-chatpad,gip-gamepad,gip-guitar,gip-headset,gip,wired}.ko.xz > /dev/null \
    || (cat /var/cache/akmods/xone/*-for-${KERNEL_VERSION}.failed.log && exit 1)

# Either successfully build and install xpadneo kernel module, or fail early with debug output
KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')" \
    && akmods --force --kernels "${KERNEL_VERSION}" --kmod xpadneo \
    && modinfo /usr/lib/modules/${KERNEL_VERSION}/extra/xpadneo/hid-xpadneo.ko.xz > /dev/null \
    || (cat /var/cache/akmods/xpadneo/*-for-${KERNEL_VERSION}.failed.log && exit 1)

install -D /etc/pki/akmods/certs/public_key.der /tmp/akmods-custom-key/rpmbuild/SOURCES/public_key.der

rpmbuild -ba \
    --define '_topdir /tmp/akmods-custom-key/rpmbuild' \
    --define '%_tmppath %{_topdir}/tmp' \
    /tmp/akmods-custom-key/akmods-custom-key.spec

