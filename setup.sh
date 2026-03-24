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

# ── STAGE 1: MODE SELECTION ───────────────────────────────────────────────────
main_menu() {
    SETUP_MODE=$(whiptail --title "PROXMOX VE 9 BOOTSTRAP" --clear --cancel-button "Exit" \
    --radiolist "SELECT SETUP MODE:" 15 65 2 \
    "FULL"     "Run all recommended tasks (includes User Setup)" ON \
    "ADVANCED" "Manually select components" OFF 3>&1 1>&2 2>&3)

    [[ $? -ne 0 ]] && exit 0

    if [[ "$SETUP_MODE" == "ADVANCED" ]]; then
        advanced_selection
    else
        FUNCTIONS="REPOS UPDATE NAG USER PASSWD CEPH HA IOMMU VFIO ZFS SAMBA TUNING HTOP TMUX CURL GIT JQ NET ESSENTIALS"
        user_config_logic
    fi
}

# ── STAGE 2: COMPONENT SELECTION ──────────────────────────────────────────────
advanced_selection() {
    CHOICES=$(whiptail --title "ADVANCED CONFIGURATION" --checklist \
    "SELECT TASKS (SPACE to select):" 26 75 16 \
    "REPOS"    "  Trixie modern source files" ON \
    "UPDATE"   "  System update & upgrade" ON \
    "NAG"      "  Disable subscription nag" ON \
    "USER"     "  Configure User (Create or Modify)" ON \
    "PASSWD"   "  Set sudo to NOPASSWD" ON \
    "CEPH"     "  Configure Ceph repo" ON \
    "HA"       "  Enable HA services" ON \
    "IOMMU"    "  Hardware passthrough (GPU)" ON \
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
    user_config_logic
}

# ── STAGE 3: INTELLIGENT USER MANAGEMENT ──────────────────────────────────────
user_config_logic() {
    if [[ $FUNCTIONS != *"USER"* ]]; then
        final_confirmation
        return
    fi

    # 1. Audit System Users
    # Get users with UID >= 1000 who are in the sudo/admin groups
    SUDO_USERS=$(grep -Po '^sudo:.*:\K.*|^admin:.*:\K.*' /etc/group | tr ',' ' ' | xargs)
    # Get all other human users (UID >= 1000) not in sudo
    ALL_HUMAN=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | xargs)
    
    USER_LIST_MSG="EXISTING SYSTEM USERS:\n"
    USER_LIST_MSG+="  • Sudo Admins: ${SUDO_USERS:-None}\n"
    USER_LIST_MSG+="  • Other Users: ${ALL_HUMAN:-None}\n\n"

    # 2. Action Menu
    USER_ACTION=$(whiptail --title "USER CONFIGURATION" --menu \
    "$USER_LIST_MSG Select your path:" 18 70 3 \
    "PROCEED" "Enter username to Create or Update" \
    "SKIP"    "Remove User/Sudo tasks from this run" 3>&1 1>&2 2>&3)

    [[ $? -ne 0 ]] && { [[ "$SETUP_MODE" == "ADVANCED" ]] && advanced_selection || main_menu; }

    if [[ "$USER_ACTION" == "SKIP" ]]; then
        FUNCTIONS=$(echo "$FUNCTIONS" | sed 's/USER//;s/PASSWD//' | xargs)
        final_confirmation
        return
    fi

    # 3. Username Input & Conflict Check
    NEW_USER=$(whiptail --title "USER SETUP" --inputbox "Enter username:" 10 60 3>&1 1>&2 2>&3)
    [[ -z "$NEW_USER" ]] && user_config_logic

    if id "$NEW_USER" &>/dev/null; then
        if ! whiptail --title "WARNING: USER EXISTS" --yesno \
        "The user '$NEW_USER' already exists.\n\nProceeding will OVERWRITE the existing password and ensure sudo privileges.\n\nContinue?" 12 65; then
            user_config_logic
            return
        fi
    fi

    # 4. Credential Collection (Sets NEW_PASS)
    # This calls your internal library function for password masking/confirmation
    get_user_credentials "$NEW_USER" 
    
    final_confirmation
}

# ── STAGE 4: FINAL SUMMARY ────────────────────────────────────────────────────
final_confirmation() {
    local SUMMARY="SUMMARY OF OPERATIONS:\n\n"
    for task in $FUNCTIONS; do SUMMARY+="  • $task\n"; done
    
    if [[ $FUNCTIONS == *"USER"* ]]; then
        SUMMARY+="\nTARGET USER: $NEW_USER\n(Password will be applied/updated)"
    fi

    if whiptail --title "FINAL CONFIRMATION" --yesno "$SUMMARY\n\nBegin execution?" 22 70; then
        execute_tasks
    else
        user_config_logic
    fi
}

# ── STAGE 5: EXECUTION ────────────────────────────────────────────────────────
execute_tasks() {
    # [Internal execution logic as previously defined...]
    # Ensure run_task and your ERRORS array loop are present here.
}

main_menu
