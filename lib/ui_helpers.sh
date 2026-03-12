#!/usr/bin/env bash

msg_ok() { echo -e "\e[32m✔ $1\e[0m"; }

get_user_credentials() {
    NEW_USER=$(whiptail --title "User Setup" --inputbox "Enter new privileged username:" 10 60 3>&1 1>&2 2>&3)
    
    # Check if user cancelled
    if [[ -z "$NEW_USER" ]]; then
        USER_ACTION="SKIP"
        return 1
    fi
    
    while true; do
        PASS1=$(whiptail --title "Password" --passwordbox "Enter password for $NEW_USER:" 10 60 3>&1 1>&2 2>&3)
        
        # Check if user cancelled
        if [[ -z "$PASS1" ]]; then
            USER_ACTION="SKIP"
            return 1
        fi
        
        PASS2=$(whiptail --title "Password" --passwordbox "Confirm password:" 10 60 3>&1 1>&2 2>&3)
        
        if [ "$PASS1" == "$PASS2" ] && [ ! -z "$PASS1" ]; then
            NEW_PASS="$PASS1"
            # Prompt user to choose action
            if whiptail --title "User Exists?" --yes-button "CREATE" --no-button "SKIP" --yesno "Create new user: $NEW_USER?" 10 60; then
                USER_ACTION="CREATE"
            else
                USER_ACTION="SKIP"
            fi
            break
        fi
        whiptail --msgbox "Passwords do not match. Try again." 10 60
    done
}
