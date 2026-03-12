apt-get install -y samba cifs-utils &>/dev/null
systemctl enable smbd && systemctl start smbd
mkdir -p /mnt/windows-shares
msg_ok "SAMBA CONFIGURED"
