#!/bin/bash

# Copyright (C) 2023 Thien Tran
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

#Meant to be run on Ubuntu Pro Minimal 
#The script assumes you already have Ubuntu Pro activated

#Compliance and updates
sudo ua enable usg
sudo apt update -y
sudo apt full-upgrade -y
sudo apt install -y usg curl libpam-pwquality
sudo apt autoremove -y
sudo usg fix cis_level2_server

# Remove AIDE
sudo apt purge -y aide*

# Setup NTS
sudo systemctl disable --now systemd-timesyncd
sudo apt install -y chrony
sudo curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/chrony.conf -o /etc/chrony/chrony.conf
sudo systemctl restart chronyd

# Setup UFW
# UFW Snap is strictly confined, unlike its .deb counterpart
sudo apt purge -y ufw
sudo snap install ufw
sudo ufw enable
sudo ufw allow OpenSSH

# Harden SSH
echo 'GSSAPIAuthentication no
VerifyHostKeyDNS yes' | sudo tee /etc/ssh/ssh_config.d/10-custom.conf
sudo chmod 644 /etc/ssh/ssh_config.d/10-custom.conf
sudo curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/ssh/sshd_config/10-custom.conf -o /etc/ssh/sshd_config.d/10-custom.conf
sudo chmod 644 /etc/ssh/sshd_config.d/10-custom.conf
sudo mkdir -p /etc/systemd/system/ssh.service.d
sudo curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/sshd.service.d/local.conf -o /etc/systemd/system/ssh.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl restart sshd

# Setup unbound

sudo apt install -y unbound

echo 'server:
  trust-anchor-signaling: yes
  root-key-sentinel: yes
  tls-cert-bundle: /etc/ssl/certs/ca-certificates.crt

  hide-identity: yes
  hide-trustanchor: yes
  hide-version: yes
  deny-any: yes
  harden-algo-downgrade: yes
  harden-large-queries: yes
  harden-referral-path: yes
  ignore-cd-flag: yes
  max-udp-size: 3072
  module-config: "validator iterator"
  qname-minimisation-strict: yes
  unwanted-reply-threshold: 10000000
  use-caps-for-id: yes

  outgoing-port-permit: 1024-65535

  prefetch: yes
  prefetch-key: yes


forward-zone:
  name: "."
  forward-tls-upstream: yes
  forward-addr: 1.1.1.2@853#security.cloudflare-dns.com
  forward-addr: 1.0.0.2@853#security.cloudflare-dns.com
  forward-addr: 2606:4700:4700::1112@853#security.cloudflare-dns.com
  forward-addr: 2606:4700:4700::1002@853#security.cloudflare-dns.com' | sudo tee /etc/unbound/unbound.conf.d/custom.conf

mkdir -p /etc/systemd/system/unbound.service.d
echo $'[Service]
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_SETGID CAP_SETUID CAP_SYS_CHROOT CAP_SYS_RESOURCE CAP_NET_RAW
MemoryDenyWriteExecute=true
NoNewPrivileges=true
PrivateDevices=true
PrivateTmp=true
ProtectHome=true
ProtectClock=true
ProtectControlGroups=true
ProtectKernelLogs=true
ProtectKernelModules=true
# This breaks using socket options like \'so-rcvbuf\'. Explicitly disable for visibility.
ProtectKernelTunables=false
ProtectProc=invisible
RestrictAddressFamilies=AF_INET AF_INET6 AF_NETLINK AF_UNIX
RestrictRealtime=true
SystemCallArchitectures=native
SystemCallFilter=~@clock @cpu-emulation @debug @keyring @module mount @obsolete @resources
RestrictNamespaces=yes
LockPersonality=yes
RestrictSUIDSGID=yes
ReadWritePaths=@UNBOUND_RUN_DIR@ @UNBOUND_CHROOT_DIR@

# Below rules are needed when chroot is enabled (usually it\'s enabled by default).
# If chroot is disabled like chroot: "" then they may be safely removed.
TemporaryFileSystem=@UNBOUND_CHROOT_DIR@/dev:ro
TemporaryFileSystem=@UNBOUND_CHROOT_DIR@/run:ro
BindReadOnlyPaths=-/run/systemd/notify:@UNBOUND_CHROOT_DIR@/run/systemd/notify
BindReadOnlyPaths=-/dev/urandom:@UNBOUND_CHROOT_DIR@/dev/urandom
BindPaths=-/dev/log:@UNBOUND_CHROOT_DIR@/dev/log' | sudo tee /etc/systemd/system/unbound.service.d/override.conf

sudo systemctl daemon-reload
sudo systemctl restart unbound
sudo systemctl disable --now systemd-resolved

# Kernel hardening
sudo curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/modprobe.d/30_security-misc.conf -o /etc/modprobe.d/30_security-misc.conf
sudo curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/990_security-misc.conf -o /etc/sysctl.d/990_security-misc.conf
sudo curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/30_silent-kernel-printk.conf -o /etc/sysctl.d/30_silent-kernel-printk.conf
sudo curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/30_security-misc_kexec-disable.conf -o /etc/sysctl.d/30_security-misc_kexec-disable.conf
sudo sed -i 's/kernel.yama.ptrace_scope=2/kernel.yama.ptrace_scope=3/g' /etc/sysctl.d/990_security-misc.conf
sudo sed -i 's/net.ipv4.icmp_echo_ignore_all=1/net.ipv4.icmp_echo_ignore_all=0/g' /etc/sysctl.d/990_security-misc.conf
sudo sed -i 's/net.ipv6.icmp.echo_ignore_all=1/net.ipv6.icmp.echo_ignore_all=0/g' /etc/sysctl.d/990_security-misc.conf
sudo sysctl -p

# Rebuild initramfs
sudo update-initramfs -u

# Disable telemetry
sudo systemctl stop apport.service
sudo systemctl disable apport.service
sudo systemctl mask apport.service
sudo systemctl stop whoopsie.service
sudo systemctl disable whoopsie.service
sudo systemctl mask whoopsie.service

#Setup fwupd
sudo apt install fwupd -y
mkdir -p /etc/systemd/system/fwupd-refresh.service.d
echo '[Service]
ExecStart=/usr/bin/fwupdmgr update' | tee /etc/systemd/system/fwupd-refresh.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl enable --now fwupd-refresh.timer

# Setup tuned
sudo apt install tuned -y
sudo tuned-adm profile virtual-guest

# Enable fstrim.timer
sudo systemctl enable --now fstrim.timer
