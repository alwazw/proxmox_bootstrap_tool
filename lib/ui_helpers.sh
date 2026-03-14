get_user_credentials() {
    # Input box with skip option
    NEW_USER=$(whiptail --title "User Setup" --inputbox \
        "Enter new privileged username:" 10 60 \
        --ok-button "Enter New Password" \
        --cancel-button "Skip — proceed without user" \
        3>&1 1>&2 2>&3)

    if [[ $? -ne 0 || -z "$NEW_USER" ]]; then
        export USER_SKIPPED=true
        return 0
    fi

    # Password entry
    NEW_PASS=$(whiptail --title "Password" --passwordbox \
        "Enter password for $NEW_USER:" 10 60 \
        --ok-button "Confirm Password" \
        --cancel-button "Skip — proceed without user" \
        3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then
        export USER_SKIPPED=true
        return 0
    fi

    export NEW_USER NEW_PASS USER_ACTION="CREATE"
    export USER_SKIPPED=false
}
