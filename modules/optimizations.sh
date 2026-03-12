msg_ok "Applying ZFS and Network Tuning"
echo "options zfs zfs_arc_max=8589934592" > /etc/modprobe.d/zfs.conf
cat <<SYS >/etc/sysctl.d/99-proxmox.conf
net.core.rmem_max=134217728
net.core.wmem_max=134217728
SYS
sysctl -p /etc/sysctl.d/99-proxmox.conf &>/dev/null
