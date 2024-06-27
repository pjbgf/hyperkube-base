FROM registry.suse.com/bci/bci-base:15.6

ARG ARCH=amd64

COPY scripts/hyperkube /hyperkube
COPY scripts/iptables-wrapper /usr/sbin/iptables-wrapper

# Adapted from: https://github.com/kubernetes/kubernetes/blob/v1.18.6/build/debian-hyperkube-base/Dockerfile
RUN ln -s /hyperkube /apiserver \
 && ln -s /hyperkube /cloud-controller-manager \
 && ln -s /hyperkube /controller-manager \
 && ln -s /hyperkube /kubectl \
 && ln -s /hyperkube /kubelet \
 && ln -s /hyperkube /proxy \
 && ln -s /hyperkube /scheduler

# The samba-common, cifs-utils, and nfs-common packages depend on
# ucf, which itself depends on /bin/bash.
# RUN echo "dash dash/sh boolean false" | debconf-set-selections

RUN rpm --import https://packages.microsoft.com/keys/microsoft.asc && \
    zypper addrepo --name 'Azure CLI' --check https://packages.microsoft.com/yumrepos/azure-cli azure-cli && \
    zypper --non-interactive refresh && \
    zypper -n install \
      arptables \
      dash \
      # ceph-common \
      cifs-utils \
      conntrack-tools \
      e2fsprogs \
      xfsprogs \
      ebtables \
      ethtool \
      git \
      # glusterfs \
      iproute2 \
      ipset \
      iptables \
      iputils \
      jq \
      kmod \
      lsb-release \
      open-iscsi \
      openssh-clients \
      nfs-client \
      samba-client \
      socat \
      udev \
      xfsprogs \
      # zfsutils-linux \
      && \
    zypper -n install --from azure-cli --no-recommends \
      azure-cli && \
    zypper -n clean -a && \
    rm -rf /tmp/* /var/tmp/* /usr/share/doc/packages/* /usr/lib/sysimage/rpm/*.db

RUN update-alternatives \
    --install /usr/sbin/iptables iptables /usr/sbin/iptables-legacy 10 \
    --slave /usr/sbin/iptables-save iptables-save /usr/sbin/iptables-legacy-save \
    --slave /usr/sbin/iptables-restore iptables-restore /usr/sbin/iptables-legacy-restore \
    --slave /usr/sbin/ip6tables ip6tables /usr/sbin/ip6tables-legacy \
    --slave /usr/sbin/ip6tables-save ip6tables-save /usr/sbin/ip6tables-legacy-save \
    --slave /usr/sbin/ip6tables-restore ip6tables-restore /usr/sbin/ip6tables-legacy-restore && \
  update-alternatives \
    --install /usr/sbin/iptables iptables /usr/sbin/iptables-nft 20 \
    --slave /usr/sbin/iptables-save iptables-save /usr/sbin/iptables-nft-save \
    --slave /usr/sbin/iptables-restore iptables-restore /usr/sbin/iptables-nft-restore \
    --slave /usr/sbin/ip6tables ip6tables /usr/sbin/ip6tables-nft \
    --slave /usr/sbin/ip6tables-save ip6tables-save /usr/sbin/ip6tables-nft-save \
    --slave /usr/sbin/ip6tables-restore ip6tables-restore /usr/sbin/ip6tables-nft-restore && \
  update-alternatives \
    --force --install /usr/sbin/iptables iptables /usr/sbin/iptables-wrapper 100 \
    --slave /usr/sbin/iptables-restore iptables-restore /usr/sbin/iptables-wrapper \
    --slave /usr/sbin/iptables-save iptables-save /usr/sbin/iptables-wrapper \
    --slave /usr/sbin/ip6tables ip6tables /usr/sbin/iptables-wrapper \
    --slave /usr/sbin/ip6tables-restore ip6tables-restore /usr/sbin/iptables-wrapper \
    --slave /usr/sbin/ip6tables-save ip6tables-save /usr/sbin/iptables-wrapper

# iptables-wrapper-installer.sh uses `iptables-nft --version` to check whether iptables-nft exists, iptables-nft returns
# the error "protocol not supported" when being invoked in an emulated enviroment whose arch (for example, arm64)
# is different from the host (amd64). So we do the check ourselves before running iptables-wrapper-installer.sh.
RUN which iptables-legacy && which iptables-nft

ENTRYPOINT ["/hyperkube"]
