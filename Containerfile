ARG IMAGE_NAME="${IMAGE_NAME:-silverblue}"
ARG IMAGE_SUFFIX="${IMAGE_SUFFIX:-main}"
ARG BASE_IMAGE="ghcr.io/ublue-os/${IMAGE_NAME}-${IMAGE_SUFFIX}"
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-37}"

FROM ${BASE_IMAGE}:${FEDORA_MAJOR_VERSION} AS builder

RUN sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-{cisco-openh264,modular,updates-modular}.repo

RUN wget https://negativo17.org/repos/fedora-steam.repo -O /etc/yum.repos.d/fedora-steam.repo && \
    rpm-ostree install \
        akmods \
        mock \
        akmod-xone \
        akmod-xpadneo

# alternatives cannot create symlinks on its own during a container build
RUN if [[ ! -e /etc/alternatives/ld ]]; then \
    ln -s /usr/bin/ld.bfd /etc/alternatives/ld && ln -s /etc/alternatives/ld /usr/bin/ld; fi

ADD certs /tmp/certs

RUN install -Dm644 /tmp/certs/public_key.der   /etc/pki/akmods/certs/public_key.der
RUN install -Dm644 /tmp/certs/private_key.priv /etc/pki/akmods/private/private_key.priv

# protect against incorrect permissions in tmp dirs with break akmods builds
RUN chmod 1777 /tmp /var/tmp

# Either successfully build and install xone kernel modules, or fail early with debug output
RUN KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')" \
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

RUN sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-{cisco-openh264,modular,updates-modular}.repo

RUN KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')" \
    RPMFUSION_ENABLED="$(grep enabled=1 /etc/yum.repos.d/rpmfusion-*.repo > /dev/null; echo $?)" \
    && \
        wget https://negativo17.org/repos/fedora-steam.repo -O /etc/yum.repos.d/fedora-steam.repo \
    && \
        if [[ "$RPMFUSION_ENABLED" == "1" ]]; then \
            sed -i '0,/enabled=0/{s/enabled=0/enabled=1/}' /etc/yum.repos.d/rpmfusion-{,non}free{,-updates}.repo; \
        fi \
    && \
        rpm-ostree install --idempotent \
            /tmp/akmods/xone/kmod-xone-${KERNEL_VERSION}-*.rpm \
            /tmp/akmods/xpadneo/kmod-xpadneo-${KERNEL_VERSION}-*.rpm \
            /tmp/akmods-custom-key/rpmbuild/RPMS/noarch/akmods-custom-key-*.rpm \
    && \
        rm -rf \
            /etc/yum.repos.d/fedora-steam.repo \
            /tmp/* \
            /var/* \
    && \
        ostree container commit \
    && \
        mkdir -p /tmp /var/tmp && \
        chmod 1777 /tmp /var/tmp
