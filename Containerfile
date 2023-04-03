ARG IMAGE_NAME="${IMAGE_NAME:-silverblue}"
ARG IMAGE_SUFFIX="${IMAGE_SUFFIX:-main}"
ARG BASE_IMAGE="ghcr.io/ublue-os/${IMAGE_NAME}-${IMAGE_SUFFIX}"
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-37}"

FROM ${BASE_IMAGE}:${FEDORA_MAJOR_VERSION} AS builder

ADD build.sh /tmp/build.sh
ADD certs /tmp/certs
ADD akmods-custom-key.spec /tmp/akmods-custom-key/akmods-custom-key.spec

RUN /tmp/build.sh

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
            /tmp/akmods/wl/kmod-wl-${KERNEL_VERSION}-*.rpm \
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
