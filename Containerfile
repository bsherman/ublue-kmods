ARG BASE_IMAGE='quay.io/fedora-ostree-desktops/silverblue'
# See https://pagure.io/releng/issue/11047 for final location
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-37}"

FROM ${BASE_IMAGE}:${FEDORA_MAJOR_VERSION} AS builder

RUN sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-{cisco-openh264,modular,updates-modular}.repo

RUN wget https://negativo17.org/repos/fedora-nvidia.repo -O /etc/yum.repos.d/fedora-nvidia.repo && \
    wget https://negativo17.org/repos/fedora-steam.repo -O /etc/yum.repos.d/fedora-steam.repo && \
    rpm-ostree install \
        akmods \
        mock \
        nvidia-driver \
        akmod-xpadneo \
        binutils \
        kernel-devel-$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')

# alternatives cannot create symlinks on its own during a container build
RUN ln -s /usr/bin/ld.bfd /etc/alternatives/ld && ln -s /etc/alternatives/ld /usr/bin/ld

ADD certs/public_key.der   /etc/pki/akmods/certs/public_key.der
ADD certs/private_key.priv /etc/pki/akmods/private/private_key.priv

RUN chmod 644 /etc/pki/akmods/{private/private_key.priv,certs/public_key.der}

# Either successfully build and install nvidia kernel modules, or fail early with debug output
RUN KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')" \
    && akmods --force --kernels "${KERNEL_VERSION}" --kmod nvidia \
    && modinfo /usr/lib/modules/${KERNEL_VERSION}/extra/nvidia/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz > /dev/null \
    || (cat /var/cache/akmods/nvidia/*-for-${KERNEL_VERSION}.failed.log && exit 1)

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
        wget https://negativo17.org/repos/fedora-nvidia.repo -O /etc/yum.repos.d/fedora-nvidia.repo && \
        wget https://negativo17.org/repos/fedora-steam.repo -O /etc/yum.repos.d/fedora-steam.repo \
    && find /tmp/akmods -type f | sort \
    && \
        rpm-ostree install \
            nvidia-driver nvidia-driver-cuda nvidia-modprobe \
            /tmp/akmods/nvidia/kmod-nvidia-${KERNEL_VERSION}-*.rpm \
            /tmp/akmods/xpadneo/kmod-xpadneo-${KERNEL_VERSION}-*.rpm \
            /tmp/akmods-custom-key/rpmbuild/RPMS/noarch/akmods-custom-key-*.rpm \
    && \
        ln -s /usr/bin/ld.bfd /etc/alternatives/ld && \
        ln -s /etc/alternatives/ld /usr/bin/ld \
    && \
        rm -rf \
            /etc/yum.repos.d/fedora-{nvidia,steam}.repo \
            /tmp/* \
            /var/* \
    && \
        ostree container commit
