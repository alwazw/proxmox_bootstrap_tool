msg_ok "Updating System & Installing Tools"
apt-get update && apt-get full-upgrade -y &>/dev/null
