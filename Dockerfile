ARG BCI_VERSION=15.6

FROM registry.suse.com/bci/bci-busybox:${BCI_VERSION} AS final
FROM registry.suse.com/bci/bci-base:${BCI_VERSION} AS builder

# original contents of the final image.
RUN mkdir /chroot
COPY --from=final / /chroot/

COPY scripts/hyperkube /chroot/hyperkube
COPY scripts/iptables-wrapper /chroot/usr/sbin/iptables-wrapper


# The final image does not contain zypper, --installroot is used to
# install all artefacts within a dir (/chroot) that can then be copied
# over to a scratch image.
RUN rpm --import https://packages.microsoft.com/keys/microsoft.asc && \
    zypper addrepo --name 'Azure CLI' --check https://packages.microsoft.com/yumrepos/azure-cli azure-cli && \
    zypper --non-interactive refresh &&  \
    zypper --non-interactive --installroot /chroot install --from azure-cli --no-recommends azure-cli


RUN rpm --import https://download.opensuse.org/repositories/filesystems/SLE_15_SP5/repodata/repomd.xml.key && \
    zypper addrepo https://download.opensuse.org/repositories/filesystems/SLE_15_SP5/filesystems.repo && \
    zypper --non-interactive refresh && \
    zypper --non-interactive --installroot /chroot install --from filesystems --no-recommends  zfs glusterfs
    
    
    # ceph-common

RUN zypper --non-interactive --installroot /chroot install --no-recommends \
      # arptables \
      dash \
      # cifs-utils \
      conntrack-tools \
      # e2fsprogs \
      # xfsprogs \
      ebtables \
      ethtool \
      git-core \
      # iproute2 \
      ipset \
      # iptables \
      iputils \
      jq \
      # kmod \
      lsb-release \
      # openssh-clients \
      # open-iscsi \
      # nfs-client \
      # samba-client \
      socat \
      # udev \
      xfsprogs

RUN zypper --installroot /chroot clean -a && \
    rm -rf /chroot/var/cache/zypp/* /chroot/var/log/zypp/* /chroot/etc/zypp/ /chroot/usr/lib/sysimage/rpm/*.db

# iptables-wrapper-installer.sh uses `iptables-nft --version` to check whether iptables-nft exists, iptables-nft returns
# the error "protocol not supported" when being invoked in an emulated enviroment whose arch (for example, arm64)
# is different from the host (amd64). So we do the check ourselves before running iptables-wrapper-installer.sh.
RUN which iptables-legacy && which iptables-nft


FROM scratch

COPY --from=builder /chroot /

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

# Adapted from: https://github.com/kubernetes/kubernetes/blob/v1.18.6/build/debian-hyperkube-base/Dockerfile
RUN ln -s /hyperkube /apiserver \
 && ln -s /hyperkube /cloud-controller-manager \
 && ln -s /hyperkube /controller-manager \
 && ln -s /hyperkube /kubectl \
 && ln -s /hyperkube /kubelet \
 && ln -s /hyperkube /proxy \
 && ln -s /hyperkube /scheduler

ENTRYPOINT ["/hyperkube"]
