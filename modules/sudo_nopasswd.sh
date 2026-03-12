chmod 440 /etc/sudoers
echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$NEW_USER
msg_ok "SUDO NOPASSWD CONFIGURED"
