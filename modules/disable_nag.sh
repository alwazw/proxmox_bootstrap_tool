sed -i 's/data.status !== "Active"/false/g' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
systemctl restart pveproxy &>/dev/null
msg_ok "NAG REMOVED"
