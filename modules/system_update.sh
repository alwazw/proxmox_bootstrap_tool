# Define the msg_ok function
msg_ok() {
  local TEXT="$1"
  echo -e " \e[32m\u2713\e[0m \e[32m$TEXT\e[0m"
}


msg_ok "Updating System & Installing Tools"
apt-get update && apt-get full-upgrade -y &>/dev/null
