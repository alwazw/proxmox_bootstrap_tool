# Define the msg_ok function
msg_ok() {
  local TEXT="$1"
  echo -e " \e[32m\u2713\e[0m \e[32m$TEXT\e[0m"
}


sed -i 's/data.status !== "Active"/false/g' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
systemctl restart pveproxy &>/dev/null
msg_ok "NAG REMOVED"
