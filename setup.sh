#!/usr/bin/env bash

# --- STANDALONE BOOTSTRAP LOGIC ---
if [[ ! -f "./lib/dep_check.sh" || ! -d "./modules" ]]; then
    if [[ -n "$STANDALONE_INTERNAL" ]]; then
        echo "✖ ERROR: Failed to initialize framework."
        exit 1
    fi
    echo "▶ Initializing full framework (standalone mode detected)..."
    TMP_DIR=$(mktemp -d)
    REPO_URL="https://github.com/alwazw/proxmox_bootstrap_tool"

    if [[ -d "../lib" && -d "../modules" ]]; then
        cp -r ../lib ../modules ../setup.sh "$TMP_DIR/"
    else
        if command -v git &>/dev/null; then
            git clone -q "$REPO_URL" "$TMP_DIR" || \
                (wget -qO- "$REPO_URL/archive/refs/heads/main.tar.gz" | tar xz -C "$TMP_DIR" --strip-components=1)
        else
            wget -qO- "$REPO_URL/archive/refs/heads/main.tar.gz" | tar xz -C "$TMP_DIR" --strip-components=1
        fi
    fi

    cd "$TMP_DIR" || exit 1
    export STANDALONE_INTERNAL=true
    exec bash "./setup.sh" "$@"
fi

source ./lib/dep_check.sh
source ./lib/sys_checks.sh
source ./lib/ui_helpers.sh

check_dependencies
check_root "false"
check_cluster "false"

# ── NAVIGATION WRAPPER ────────────────────────────────────────────────────────
main_menu() {
    SETUP_MODE=$(whiptail --title "PROXMOX VE 9 BOOTSTRAP" --clear --cancel-button "Exit" \
    --radiolist "SELECT SETUP MODE:" 15 65 2 \
    "FULL"     "Run all recommended tasks" ON \
    "ADVANCED" "Manually select components" OFF 3>&1 1>&2 2>&3)

    [[ $? -ne 0 ]] && exit 0

    if [[ "$SETUP_MODE" == "ADVANCED" ]]; then
        advanced_selection
    else
        FUNCTIONS="REPOS UPDATE NAG USER PASSWD CEPH HA IOMMU VFIO ZFS SAMBA TUNING HTOP TMUX CURL GIT JQ NET ESSENTIALS"
        user_logic_flow
    fi
}

advanced_selection() {
    CHOICES=$(whiptail --title "ADVANCED CONFIGURATION" --checklist \
    "SELECT TASKS (SPACE to select):" 26 75 16 \
    "REPOS"    "  Trixie modern source files" ON \
    "UPDATE"   "  System update & upgrade" ON \
    "NAG"      "  Disable subscription nag" ON \
    "USER"     "  Create/Manage sudo user" ON \
    "PASSWD"   "  Set sudo to NOPASSWD" ON \
    "CEPH"     "  Configure Ceph repo" ON \
    "HA"       "  Enable HA services" ON \
    "IOMMU"    "  Hardware passthrough" ON \
    "VFIO"     "  Load VFIO modules" ON \
    "ZFS"      "  ZFS tune & scrub" ON \
    "SAMBA"    "  Samba/CIFS mount" ON \
    "TUNING"   "  Network stack tuning" ON \
    "ESSENTIALS" "Fail2ban, Chrony, Smartd" ON \
    "TMUX"     "  Install tmux" ON \
    "HTOP"     "  Install htop" ON \
    "CURL"     "  Install curl/wget" ON 3>&1 1>&2 2>&3)

    [[ $? -ne 0 ]] && main_menu

    FUNCTIONS=$(echo "$CHOICES" | tr -d '"')
    user_logic_flow
}

user_logic_flow() {
    if [[ $FUNCTIONS == *"USER"* ]]; then
        # Fetch current non-system users (UID >= 1000)
        EXISTING_USERS=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | xargs)
        
        USER_CHOICE=$(whiptail --title "USER MANAGEMENT" --menu \
        "Current Users: ${EXISTING_USERS:-None}\n\nSelect action:" 15 65 3 \
        "CREATE" "Create a new privileged user" \
        "EXISTING" "Use an existing user for sudo config" \
        "SKIP" "Do not perform user/sudo setup" 3>&1 1>&2 2>&3)

        case $USER_CHOICE in
            CREATE)
                get_user_credentials # Updates NEW_USER, NEW_PASS
                ;;
            EXISTING)
                NEW_USER=$(whiptail --inputbox "Enter existing username to configure:" 10 60 3>&1 1>&2 2>&3)
                ;;
            *)
                FUNCTIONS=$(echo "$FUNCTIONS" | sed 's/USER//;s/PASSWD//' | xargs)
                ;;
        esac
    fi
    final_confirmation
}

final_confirmation() {
    SUMMARY="READY TO EXECUTE:\n"
    for task in $FUNCTIONS; do SUMMARY+=" • $task\n"; done
    [[ -n "$NEW_USER" ]] && SUMMARY+="\nTARGET USER: $NEW_USER"

    whiptail --title "FINAL CONFIRMATION" --yesno "$SUMMARY\n\nProceed with installation?" 20 70 3>&1 1>&2 2>&3
    
    if [[ $? -eq 0 ]]; then
        execute_tasks
    else
        main_menu
    fi
}

# ── EXECUTION ─────────────────────────────────────────────────────────────────
execute_tasks() {
    # ... [Same task execution loop as your previous script] ...
    # Ensure run_task and ERRORS array are included here
}

main_menu
