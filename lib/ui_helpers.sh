#!/usr/bin/env bash

msg_ok() { echo -e "\e[32m✔ $1\e[0m"; }

get_user_credentials() {
    while true; do
        # --- Screen: Username ---
        # Buttons: Next, More Options, Back
        NEW_USER=$(whiptail --title "User Setup" \
            --ok-button "Next" \
            --cancel-button "Back" \
            --extra-button --extra-label "More Options" \
            --inputbox "Enter new privileged username:" 10 60 3>&1 1>&2 2>&3)
        STATUS=$?
        
        if [[ $STATUS -eq 1 ]]; then return 1; fi # BACK
        if [[ $STATUS -eq 255 ]]; then return 2; fi # ESC/EXIT

        if [[ $STATUS -eq 3 ]]; then # MORE OPTIONS
            OPT=$(whiptail --title "User Setup Options" \
                --menu "Choose an action:" 12 60 2 \
                "SKIP" "Proceed without creating a user" \
                "EXIT" "Terminate setup" \
                3>&1 1>&2 2>&3)
            if [[ "$OPT" == "SKIP" ]]; then return 3; fi
            if [[ "$OPT" == "EXIT" ]]; then return 2; fi
            continue # Back to username input
        fi
        
        if [[ -z "$NEW_USER" ]]; then
            whiptail --msgbox "Username cannot be empty." 10 40
            continue
        fi

        while true; do
            # --- Screen: Password ---
            # Buttons: Confirm, More Options, Back (to username)
            PASS1=$(whiptail --title "Password" \
                --ok-button "Confirm" \
                --cancel-button "Back to Username" \
                --extra-button --extra-label "More Options" \
                --passwordbox "Enter password for $NEW_USER:" 10 60 3>&1 1>&2 2>&3)
            STATUS=$?

            if [[ $STATUS -eq 1 ]]; then break; fi # BACK TO USERNAME INPUT
            if [[ $STATUS -eq 255 ]]; then return 2; fi # EXIT

            if [[ $STATUS -eq 3 ]]; then # MORE OPTIONS
                OPT=$(whiptail --title "Password Options" \
                    --menu "Choose an action:" 12 60 2 \
                    "SKIP" "Proceed without creating a user" \
                    "EXIT" "Terminate setup" \
                    3>&1 1>&2 2>&3)
                if [[ "$OPT" == "SKIP" ]]; then return 3; fi
                if [[ "$OPT" == "EXIT" ]]; then return 2; fi
                continue # Back to password input
            fi

            # --- Screen: Confirm Password ---
            # Buttons: Next, Modify Password, More Options
            PASS2=$(whiptail --title "Password Confirmation" \
                --ok-button "Next" \
                --cancel-button "Modify Password" \
                --extra-button --extra-label "More Options" \
                --passwordbox "Confirm password:" 10 60 3>&1 1>&2 2>&3)
            STATUS=$?

            if [[ $STATUS -eq 1 ]]; then continue; fi # BACK TO PASS1
            if [[ $STATUS -eq 255 ]]; then return 2; fi # EXIT

            if [[ $STATUS -eq 3 ]]; then # MORE OPTIONS
                OPT=$(whiptail --title "Confirmation Options" \
                    --menu "Choose an action:" 12 60 2 \
                    "SKIP" "Proceed without creating a user" \
                    "EXIT" "Terminate setup" \
                    3>&1 1>&2 2>&3)
                if [[ "$OPT" == "SKIP" ]]; then return 3; fi
                if [[ "$OPT" == "EXIT" ]]; then return 2; fi
                continue # Back to confirm password input
            fi

            if [[ "$PASS1" == "$PASS2" && -n "$PASS1" ]]; then
                NEW_PASS="$PASS1"
                USER_ACTION="CREATE"
                return 0 # SUCCESS
            fi
            whiptail --msgbox "Passwords do not match or are empty. Try again." 10 60
        done
    done
}
