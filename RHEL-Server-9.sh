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

#Assuming that you are using ANSSI-BP-028

# Setup NTS
sudo curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/chrony.conf -o /etc/chrony.conf

echo '# Command-line options for chronyd
OPTIONS="-F 1"' | sudo tee /etc/sysconfig/chronyd

sudo systemctl restart chronyd

# Setup Firewalld

sudo firewall-cmd --permanent --remove-service=cockpit
sudo firewall-cmd --reload

# Harden SSH
mkdir -p /etc/ssh/ssh_config.d /etc/ssh/sshd_config.d
echo 'GSSAPIAuthentication no
VerifyHostKeyDNS yes' | sudo tee /etc/ssh/ssh_config.d/10-custom.conf
sudo chmod 644 /etc/ssh/ssh_config.d/10-custom.conf
sudo curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/ssh/sshd_config/10-custom.conf -o /etc/ssh/sshd_config.d/10-custom.conf
sudo chmod 644 /etc/ssh/sshd_config.d/10-custom.conf
sudo curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/sshd.service.d/local.conf -o /etc/systemd/system/sshd.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl restart sshd

# Kernel hardening

sudo curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/modprobe.d/30_security-misc.conf -o /etc/modprobe.d/30_security-misc.conf
sudo curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/990_security-misc.conf -o /etc/sysctl.d/990_security-misc.conf
sudo sed -i 's/kernel.yama.ptrace_scope=2/kernel.yama.ptrace_scope=3/g' /etc/sysctl.d/990_security-misc.conf
sudo sed -i 's/net.ipv4.icmp_echo_ignore_all=1/net.ipv4.icmp_echo_ignore_all=0/g' /etc/sysctl.d/990_security-misc.conf
sudo sed -i 's/net.ipv6.icmp.echo_ignore_all=1/net.ipv6.icmp.echo_ignore_all=0/g' /etc/sysctl.d/990_security-misc.conf
sudo curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/30_silent-kernel-printk.conf -o /etc/sysctl.d/30_silent-kernel-printk.conf
sudo curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/30_security-misc_kexec-disable.conf -o /etc/sysctl.d/30_security-misc_kexec-disable.conf
sudo grubby --update-kernel=ALL --args='spectre_v2=on spec_store_bypass_disable=on l1tf=full,force mds=full,nosmt tsx=off tsx_async_abort=full,nosmt kvm.nx_huge_pages=force nosmt=force l1d_flush=on mmio_stale_data=full,nosmt random.trust_bootloader=off random.trust_cpu=off intel_iommu=on amd_iommu=on efi=disable_early_pci_dma iommu.passthrough=0 iommu.strict=1 slab_nomerge init_on_alloc=1 init_on_free=1 pti=on vsyscall=none page_alloc.shuffle=1 randomize_kstack_offset=on extra_latent_entropy debugfs=off'
sudo dracut -f
sudo sysctl -p

# Systemd hardening

sudo mkdir -p /etc/systemd/system/NetworkManager.service.d
sudo curl https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/NetworkManager.service.d/99-brace.conf -o /etc/systemd/system/NetworkManager.service.d/99-brace.conf
sudo systemctl daemon-reload
sudo systemctl restart NetworkManager

sudo mkdir -p /etc/systemd/system/irqbalance.service.d
sudo curl https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/irqbalance.service.d/99-brace.conf -o /etc/systemd/system/irqbalance.service.d/99-brace.conf
sudo systemctl daemon-reload
sudo systemctl restart irqbalance

# Setup dnf
sudo curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/dnf/dnf.conf -o /etc/dnf/dnf.conf
sudo sed -i 's/^metalink=.*/&\&protocol=https/g' /etc/yum.repos.d/*

# Setup unbound

sudo dnf install unbound -y

echo 'server:
  chroot: ""

  auto-trust-anchor-file: "/var/lib/unbound/root.key"
  trust-anchor-signaling: yes
  root-key-sentinel: yes

  tls-ciphers: "PROFILE=SYSTEM"

  hide-http-user-agent: yes
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
  forward-addr: 2606:4700:4700::1002@853#security.cloudflare-dns.com' | sudo tee /etc/unbound/unbound.conf

mkdir -p /etc/systemd/system/unbound.service.d
echo $'[Service]
MemoryDenyWriteExecute=true
PrivateDevices=true
PrivateTmp=true
ProtectHome=true
ProtectClock=true
ProtectControlGroups=true
ProtectKernelLogs=true
ProtectKernelModules=true
# This breaks using socket options like \'so-rcvbuf\'. Explicitly disable for visibility.
ProtectKernelTunables=true
ProtectProc=invisible
RestrictAddressFamilies=AF_INET AF_INET6 AF_NETLINK AF_UNIX
RestrictRealtime=true
SystemCallArchitectures=native
SystemCallFilter=~@clock @cpu-emulation @debug @keyring @module mount @obsolete @resources
RestrictNamespaces=yes
LockPersonality=yes' | sudo tee /etc/systemd/system/unbound.service.d/override.conf

sudo systemctl enable --now unbound

# Setup yara
sudo dnf install -y yara
sudo insights-client --collector malware-detection
sudo sed -i 's/test_scan: true/test_scan: false/' /etc/insights-client/malware-detection-config.yml

# Setup automatic updates

sudo sed -i 's/apply_updates = no/apply_updates = yes\nreboot = when-needed/g' /etc/dnf/automatic.conf
sudo systemctl enable --now dnf-automatic.timer

#Setup fwupd
sudo dnf install fwupd -y
echo 'UriSchemes=file;https' | sudo tee -a /etc/fwupd/fwupd.conf
sudo systemctl restart fwupd
mkdir -p /etc/systemd/system/fwupd-refresh.service.d
echo '[Service]
ExecStart=/usr/bin/fwupdmgr update' | tee /etc/systemd/system/fwupd-refresh.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl enable --now fwupd-refresh.timer

# Setup tuned
sudo dnf install tuned -y
sudo tuned-adm profile virtual-guest

# Enable fstrim.timer
sudo systemctl enable --now fstrim.timer