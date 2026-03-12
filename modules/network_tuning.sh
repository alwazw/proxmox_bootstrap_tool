#!/usr/bin/env bash
cat <<SYS > /etc/sysctl.d/99-proxmox-network.conf
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.ipv4.tcp_rmem=4096 87380 134217728
net.ipv4.tcp_wmem=4096 65536 134217728
SYS
sysctl -p /etc/sysctl.d/99-proxmox-network.conf &>/dev/null
msg_ok "NETWORK TUNED"
