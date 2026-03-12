#!/usr/bin/env bash
msg_ok() { echo -e "\e[32m✔ $1\e[0m"; }

get_user_credentials() {
    NEW_USER=$(whiptail --title "User Setup" --inputbox "Enter new privileged username:" 10 60 3>&1 1>&2 2>&3)
    while true; do
        PASS1=$(whiptail --title "Password" --passwordbox "Enter password for $NEW_USER:" 10 60 3>&1 1>&2 2>&3)
        PASS2=$(whiptail --title "Password" --passwordbox "Confirm password:" 10 60 3>&1 1>&2 2>&3)
        if [ "$PASS1" == "$PASS2" ] && [ ! -z "$PASS1" ]; then
            NEW_PASS="$PASS1"
            break
        fi
        whiptail --msgbox "Passwords do not match. Try again." 10 60
    done
}
