ARG BASE_IMAGE='quay.io/fedora-ostree-desktops/silverblue'
# See https://pagure.io/releng/issue/11047 for final location
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-37}"

FROM ${BASE_IMAGE}:${FEDORA_MAJOR_VERSION} AS builder

ARG NVIDIA_MAJOR_VERSION="${NVIDIA_MAJOR_VERSION:-525}"

RUN sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-{cisco-openh264,modular,updates-modular}.repo

RUN rpm-ostree install \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
        fedora-repos-archive

# nvidia 520.xxx and newer currently don't have a -$VERSIONxx suffix in their
# package names
RUN if [ "${NVIDIA_MAJOR_VERSION}" -ge 520 ]; then echo "nvidia"; else echo "nvidia-${NVIDIA_MAJOR_VERSION}xx"; fi > /tmp/nvidia-package-name.txt

RUN rpm-ostree install \
        akmods \
        mock \
        xorg-x11-drv-$(cat /tmp/nvidia-package-name.txt)-{,cuda,devel,kmodsrc,power}*:${NVIDIA_MAJOR_VERSION}.*.fc$(rpm -E '%fedora.%_arch')  \
        binutils \
        kernel-devel-$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')

# add xpadneo after existing ostree install completes
RUN curl -sLO https://copr.fedorainfracloud.org/coprs/atim/xpadneo/repo/fedora-$(rpm -E %fedora)/atim-xpadneo-fedora-$(rpm -E %fedora).repo --output-dir /etc/yum.repos.d/
RUN rpm-ostree install xpadneo

# alternatives cannot create symlinks on its own during a container build
RUN ln -s /usr/bin/ld.bfd /etc/alternatives/ld && ln -s /etc/alternatives/ld /usr/bin/ld

ADD certs/public_key.der   /etc/pki/akmods/certs/public_key.der
ADD certs/private_key.priv /etc/pki/akmods/private/private_key.priv

RUN chmod 644 /etc/pki/akmods/{private/private_key.priv,certs/public_key.der}

# Either successfully build and install the kernel modules, or fail early with debug output
RUN NVIDIA_PACKAGE_NAME="$(cat /tmp/nvidia-package-name.txt)" \
    KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')" \
    NVIDIA_VERSION="$(basename "$(rpm -q "xorg-x11-drv-$(cat /tmp/nvidia-package-name.txt)" --queryformat '%{VERSION}-%{RELEASE}')" ".fc$(rpm -E '%fedora')")" \
    && \
        echo $NVIDIA_VERSION && akmods --force --kernels "${KERNEL_VERSION}" --kmod "${NVIDIA_PACKAGE_NAME}" \
    && \
        modinfo /usr/lib/modules/${KERNEL_VERSION}/extra/${NVIDIA_PACKAGE_NAME}/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz > /dev/null \
    || \
        (cat /var/cache/akmods/${NVIDIA_PACKAGE_NAME}/${NVIDIA_VERSION}-for-${KERNEL_VERSION}.failed.log && exit 1)

# After nvidia, either successfully build and install xpadneo kernel module, or fail early with debug output
RUN KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')" \
    XPADNEO_VERSION="$(basename "$(rpm -q "xpadneo" --queryformat '%{VERSION}-%{RELEASE}')" ".fc$(rpm -E '%fedora')")" \
    && akmods --force --kernels "${KERNEL_VERSION}" --kmod xpadneo \
    && modinfo /usr/lib/modules/${KERNEL_VERSION}/extra/xpadneo/hid-xpadneo.ko.xz > /dev/null \
    || (cat /var/cache/akmods/xpadneo/${XPADNEO_VERSION}-for-${KERNEL_VERSION}.failed.log && exit 1)

ADD akmods-custom-key.spec /tmp/akmods-custom-key/akmods-custom-key.spec

RUN install -D /etc/pki/akmods/certs/public_key.der /tmp/akmods-custom-key/rpmbuild/SOURCES/public_key.der

RUN rpmbuild -ba \
    --define '_topdir /tmp/akmods-custom-key/rpmbuild' \
    --define '%_tmppath %{_topdir}/tmp' \
    /tmp/akmods-custom-key/akmods-custom-key.spec


RUN cp /tmp/nvidia-package-name.txt /var/cache/akmods/nvidia-package-name.txt
RUN echo "${NVIDIA_MAJOR_VERSION}" > /var/cache/akmods/nvidia-major-version.txt
RUN rpm -q "xorg-x11-drv-$(cat /tmp/nvidia-package-name.txt)" \
    --queryformat '%{EPOCH}:%{VERSION}-%{RELEASE}.%{ARCH}' > /var/cache/akmods/nvidia-full-version.txt
RUN rpm -q "xpadneo" \
    --queryformat '%{EPOCH}:%{VERSION}-%{RELEASE}.%{ARCH}' > /var/cache/akmods/xpadneo-full-version.txt

FROM ${BASE_IMAGE}:${FEDORA_MAJOR_VERSION}

COPY --from=builder /var/cache/akmods      /tmp/akmods
COPY --from=builder /tmp/akmods-custom-key /tmp/akmods-custom-key

RUN KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')" \
    NVIDIA_FULL_VERSION="$(cat /tmp/akmods/nvidia-full-version.txt)" \
    NVIDIA_PACKAGE_NAME="$(cat /tmp/akmods/nvidia-package-name.txt)" \
    XPADNEO_FULL_VERSION="$(cat /tmp/akmods/xpadneo-full-version.txt)" \
    && \
        curl -sLO https://copr.fedorainfracloud.org/coprs/atim/xpadneo/repo/fedora-$(rpm -E %fedora)/atim-xpadneo-fedora-$(rpm -E %fedora).repo --output-dir /etc/yum.repos.d/ \
    && \
        rpm-ostree install \
            https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
            https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
    && \
        rpm-ostree install \
            xorg-x11-drv-${NVIDIA_PACKAGE_NAME}-{,cuda-,devel-,kmodsrc-,power-}${NVIDIA_FULL_VERSION} \
            kernel-devel-${KERNEL_VERSION} \
            "/tmp/akmods/${NVIDIA_PACKAGE_NAME}/kmod-${NVIDIA_PACKAGE_NAME}-${KERNEL_VERSION}-${NVIDIA_FULL_VERSION#*:}.rpm" \
            xpadneo "/tmp/akmods/xpadneo/kmod-xpadneo-${KERNEL_VERSION}-${XPADNEO_FULL_VERSION#*:}.rpm" \
            /tmp/akmods-custom-key/rpmbuild/RPMS/noarch/akmods-custom-key-*.rpm \
    && \
        ln -s /usr/bin/ld.bfd /etc/alternatives/ld && \
        ln -s /etc/alternatives/ld /usr/bin/ld \
    && \
        rpm -e rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
               rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
    && \
        rm -rf \
            /tmp/* \
            /var/* \
            /etc/yum.repos.d/atim-xpadneo-fedora-$(rpm -E %fedora).repo \
    && \
        ostree container commit
