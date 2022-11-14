#!/bin/sh

# Provision FRR Debian Cloud image
# Some inspiration was taken from
# https://www.uni-koeln.de/~pbogusze/posts/Building_64bit_alpine_linux_GNS3_FRRouting_appliance.html

set -ex

export DEBIAN_FRONTEND=noninteractive

# Modify GRUB to
# - Setup serial console
# - Use legacy network interface names (eth<N>)
# - Noisy boot
sed -i -e 's/^#\?\(GRUB_TERMINAL\)=.*/\1=console/' /etc/default/grub
sed -i -e 's/^#\?\(GRUB_CMDLINE_LINUX\)=.*/\1="console=ttyS0,115200 console=tty0 net.ifnames=0 biosdevname=0"/' /etc/default/grub
sed -i -e 's/^#\?\(GRUB_CMDLINE_LINUX_DEFAULT\)=.*/\1=""/' /etc/default/grub

update-grub2

# Set the serial console for root autologin
mkdir -p /etc/systemd/system/serial-getty@ttyS0.service.d
cat <<'EOF' | tee /etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --keep-baud 115200,57600,38400,9600 --autologin root %I $TERM
EOF
systemctl daemon-reload

# Prepare /etc/hosts. We only need local hosts
cat <<'EOF' | tee /etc/hosts 1>&2
127.0.0.1	localhost

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

# Replace the interfaces file. We want 8 interfaces.
printf 'auto lo\niface lo inet loopback\n' | tee /etc/network/interfaces 1>&2
seq 0 7 | xargs -I {} printf '\nauto eth%d\niface eth%d inet manual\n' {} {} | tee -a /etc/network/interfaces 1>&2
# Add a sample of VRRP configuration since it is easy to forget and it is better
# to copy/paste it.
cat <<'EOF' | tee -a /etc/network/interfaces 1>&2

# VRRP configuration example for VRID 45 => 0x2d
#
#auto eth0
#iface eth0 inet manual
#    up ip link add vrrp4-45 link eth0 addrgenmode random type macvlan mode bridge
#    up ip link set dev vrrp4-45 address 00:00:5e:00:01:2d
#    up ip addr add 10.0.2.16/24 dev vrrp4-45
#    up ip link set dev vrrp4-45 up
#    up ip link add vrrp6-45 link eth0 addrgenmode random type macvlan mode bridge
#    up ip link set dev vrrp6-45 address 00:00:5e:00:02:2d
#    up ip addr add 2001:db8::370:7334/64 dev vrrp6-45
#    up ip link set dev vrrp6-45 up
EOF

# Enable IP and IPv6 forwarding
cat <<'EOF' | tee /etc/sysctl.d/99-ip-forwarding.conf 1>&2
net.ipv4.ip_forward=1
net.ipv4.conf.all.forwarding=1
net.ipv6.conf.all.forwarding=1
EOF

# MPLS modules and configuration
cat <<'EOF' | tee /etc/modules-load.d/mpls.conf 1>&2
mpls_router
mpls_iptunnel
EOF

cat <<'EOF' | tee /etc/sysctl.d/99-mpls.conf 1>&2
net.mpls.platform_labels=1048575
net.mpls.conf.lo.input=1
EOF
seq 0 7 | xargs -I{} printf 'net.mpls.conf.eth%d.input=1\n' {} | tee -a /etc/sysctl.d/99-mpls.conf 1>&2

# Install some prerequisite packages:
# - curl: for downloading during provisioning
# - gnupg: key management
# - mtr: arguably superior traceroutes
apt-get -y update
apt-get -y install curl gnupg mtr-tiny

# Setup FRR official Debian repository
# See https://deb.frrouting.org/
# Apply Debian guidelines from
#   https://wiki.debian.org/DebianRepository/UseThirdParty
. /etc/os-release
test -n "${VERSION_CODENAME}"
FRRVER=frr-stable
mkdir -p /etc/apt/keyrings
curl https://deb.frrouting.org/frr/keys.asc -o /etc/apt/keyrings/frr.asc
gpg --batch --yes -o /etc/apt/keyrings/frr.gpg --dearmor /etc/apt/keyrings/frr.asc
cat <<EOF | tee /etc/apt/sources.list.d/frr.list 1>&2
deb [signed-by=/etc/apt/keyrings/frr.gpg] https://deb.frrouting.org/frr ${VERSION_CODENAME} ${FRRVER}
EOF

# Install FRR
apt-get -y update
apt-get -y install frr frr-pythontools

# Configure all daemons to run by default
sed -i -E -e 's/^(bgp|ospf|ospf6|rip|ripng|isis|pim|ldp|nhrp|eigrp|babel|sharp|pbr|bfd|fabric|vrrp|path)d=.*/\1d=yes/' /etc/frr/daemons

# Save the installed FRR package version
FRR_DEB_VERSION="$(dpkg-query -W -f '${Version}' frr)"
test -n "${FRR_DEB_VERSION}"
echo "${FRR_DEB_VERSION}" > /etc/frr-version

# Final cosmetic touches
# Replace the static MOTD
cat <<EOF | tee /etc/motd

FRR Debian Cloud GNS3 Appliance
${PRETTY_NAME}
FRR Version: ${FRR_DEB_VERSION}

Run "vtysh" to access FRR's VTY shell
EOF

# Cleanup. Also remove packages that were useful only as a part of the
# provisioning to save on space.
apt-get -y purge curl gnupg
apt-get -y autoremove
dpkg -l | awk '/^rc/{print $2}' | xargs -r -t apt-get -y purge
apt-get -y clean
rm -rf /var/lib/apt/lists/*
# If we are running on virtio-scsi the following will allow to reclaim space
fstrim -v -A
