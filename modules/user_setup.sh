if [[ "$USER_ACTION" == "CREATE" ]]; then
    useradd -m -s /bin/bash "$NEW_USER"
    echo "$NEW_USER:$NEW_PASS" | chpasswd
elif [[ "$USER_ACTION" == "RESET" ]]; then
    echo "$NEW_USER:$NEW_PASS" | chpasswd
fi
if [[ "$USER_ACTION" != "SKIP" ]]; then
    usermod -aG sudo "$NEW_USER"
    echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$NEW_USER"
    chmod 0440 "/etc/sudoers.d/$NEW_USER"
    msg_ok "USER $NEW_USER CONFIGURED"
fi
