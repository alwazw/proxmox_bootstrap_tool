get_user_credentials() {
<<<<<<< HEAD
    # Buttons: Next (OK), Back (Cancel), Skip (Extra)
    # ESC will exit setup via setup.sh exit code handling
    NEW_USER=$(whiptail --title "User Setup" --ok-button "Next" --cancel-button "Back" --extra-button --extra-label "Skip" \
    --inputbox "Enter new privileged username:" 10 60 3>&1 1>&2 2>&3)
    STATUS=$?

    if [[ $STATUS -eq 3 ]]; then return 3; fi # SKIP
    if [[ $STATUS -eq 1 ]]; then return 1; fi # BACK
    if [[ $STATUS -ne 0 ]]; then return 2; fi # EXIT (ESC)
    
    if [[ -z "$NEW_USER" ]]; then
        whiptail --msgbox "Username cannot be empty." 10 40
        return 5 # Re-run username input
    fi
    
    while true; do
        # Buttons: Confirm (OK), Modify User (Cancel), Skip (Extra)
        PASS1=$(whiptail --title "Password" --ok-button "Confirm" --cancel-button "Modify User" --extra-button --extra-label "Skip" \
        --passwordbox "Enter password for $NEW_USER:" 10 60 3>&1 1>&2 2>&3)
        STATUS=$?
        
        if [[ $STATUS -eq 3 ]]; then return 3; fi # SKIP
        if [[ $STATUS -eq 1 ]]; then return 5; fi # BACK TO USERNAME INPUT
        if [[ $STATUS -ne 0 ]]; then return 2; fi # EXIT

        # Buttons: Next (OK), Modify Pass (Cancel), Skip (Extra)
        PASS2=$(whiptail --title "Password" --ok-button "Next" --cancel-button "Modify Password" --extra-button --extra-label "Skip" \
        --passwordbox "Confirm password:" 10 60 3>&1 1>&2 2>&3)
        STATUS=$?
        
        if [[ $STATUS -eq 3 ]]; then return 3; fi # SKIP
        if [[ $STATUS -eq 1 ]]; then continue; fi # RE-ENTER PASS1
        if [[ $STATUS -ne 0 ]]; then return 2; fi # EXIT
        
        if [ "$PASS1" == "$PASS2" ] && [ ! -z "$PASS1" ]; then
            NEW_PASS="$PASS1"
            USER_ACTION="CREATE"
            return 0 # SUCCESS
        fi
        whiptail --msgbox "Passwords do not match. Try again." 10 60
    done
=======
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
>>>>>>> origin/main
}
