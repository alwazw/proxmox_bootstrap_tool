msg_ok "Updating System & Installing Tools"
apt-get update && apt-get full-upgrade -y &>/dev/null
apt-get install -y htop tmux curl wget git jq net-tools &>/dev/null
