ARG IMAGE_NAME="${IMAGE_NAME:-silverblue-nvidia}"
ARG BASE_IMAGE="ghcr.io/ublue-os/${IMAGE_NAME}"
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-37}"

FROM ${BASE_IMAGE}:${FEDORA_MAJOR_VERSION} AS builder

RUN sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-{cisco-openh264,modular,updates-modular}.repo

RUN wget https://negativo17.org/repos/fedora-steam.repo -O /etc/yum.repos.d/fedora-steam.repo && \
    rpm-ostree install \
        akmods \
        mock \
        akmod-xone \
        akmod-xpadneo \
        binutils \
        kernel-devel-$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')

# alternatives cannot create symlinks on its own during a container build


ADD certs/public_key.der   /etc/pki/akmods/certs/public_key.der
ADD certs/private_key.priv /etc/pki/akmods/private/private_key.priv

RUN chmod 644 /etc/pki/akmods/{private/private_key.priv,certs/public_key.der}

# TODO: discover why this is needed for building on ublue-os/silverblue-nvidia but not official silverblue
RUN chmod 1777 /var/tmp

# Either successfully build and install xone kernel modules, or fail early with debug output
RUN KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')" \
    && ls -la /var/tmp \
    && echo "foobar" > /var/tmp/foobar \
    && ls -la /var/tmp \
    && akmods --force --kernels "${KERNEL_VERSION}" --kmod xone \
    && modinfo /usr/lib/modules/${KERNEL_VERSION}/extra/xone/xone-{dongle,gip-chatpad,gip-gamepad,gip-guitar,gip-headset,gip,wired}.ko.xz > /dev/null \
    || (cat /var/cache/akmods/xone/*-for-${KERNEL_VERSION}.failed.log && exit 1)

# Either successfully build and install xpadneo kernel module, or fail early with debug output
RUN KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')" \
    && akmods --force --kernels "${KERNEL_VERSION}" --kmod xpadneo \
    && modinfo /usr/lib/modules/${KERNEL_VERSION}/extra/xpadneo/hid-xpadneo.ko.xz > /dev/null \
    || (cat /var/cache/akmods/xpadneo/*-for-${KERNEL_VERSION}.failed.log && exit 1)

ADD akmods-custom-key.spec /tmp/akmods-custom-key/akmods-custom-key.spec

RUN install -D /etc/pki/akmods/certs/public_key.der /tmp/akmods-custom-key/rpmbuild/SOURCES/public_key.der

RUN rpmbuild -ba \
    --define '_topdir /tmp/akmods-custom-key/rpmbuild' \
    --define '%_tmppath %{_topdir}/tmp' \
    /tmp/akmods-custom-key/akmods-custom-key.spec


FROM ${BASE_IMAGE}:${FEDORA_MAJOR_VERSION}

COPY --from=builder /var/cache/akmods      /tmp/akmods
COPY --from=builder /tmp/akmods-custom-key /tmp/akmods-custom-key

RUN KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')" \
    && \
        wget https://negativo17.org/repos/fedora-steam.repo -O /etc/yum.repos.d/fedora-steam.repo \
    && find /tmp/akmods -type f | sort \
    && \
        rpm-ostree install \
            /tmp/akmods/xone/kmod-xone-${KERNEL_VERSION}-*.rpm \
            /tmp/akmods/xpadneo/kmod-xpadneo-${KERNEL_VERSION}-*.rpm \
            /tmp/akmods-custom-key/rpmbuild/RPMS/noarch/akmods-custom-key-*.rpm \
    && \
        rm -rf \
            /etc/yum.repos.d/fedora-steam.repo \
            /tmp/* \
            /var/* \
    && \
        ostree container commit
