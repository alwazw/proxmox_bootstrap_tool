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

# ── NAVIGATION LOGIC ──────────────────────────────────────────────────────────

# Stage 1: Main Mode
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
        user_management_flow
    fi
}

# Stage 2: Advanced Component Selection
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
    user_management_flow
}

# Stage 3: User Logic
user_management_flow() {
    if [[ $FUNCTIONS == *"USER"* ]]; then
        # Identify non-system users (UID >= 1000) to help user avoid conflicts
        EXISTING=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | xargs)
        
        USER_ACTION=$(whiptail --title "USER MANAGEMENT" --menu \
        "Current Users: ${EXISTING:-None}\n\nSelect how to handle user setup:" 15 65 3 \
        "CREATE"   "Create a brand new sudo user" \
        "EXISTING" "Use an existing user for configurations" \
        "SKIP"     "Skip user/sudo tasks entirely" 3>&1 1>&2 2>&3)

        [[ $? -ne 0 ]] && { [[ "$SETUP_MODE" == "ADVANCED" ]] && advanced_selection || main_menu; }

        case $USER_ACTION in
            CREATE)
                # Calls your existing ui_helpers/lib function
                get_user_credentials 
                ;;
            EXISTING)
                NEW_USER=$(whiptail --inputbox "Enter the existing username to authorize:" 10 60 3>&1 1>&2 2>&3)
                [[ -z "$NEW_USER" ]] && user_management_flow
                ;;
            SKIP)
                # Strip USER and PASSWD from the task list
                FUNCTIONS=$(echo "$FUNCTIONS" | sed 's/USER//;s/PASSWD//' | xargs)
                ;;
        esac
    fi
    final_confirmation
}

# Stage 4: Execution Confirmation
final_confirmation() {
    local SUMMARY="THE FOLLOWING TASKS WILL BE PERFORMED:\n\n"
    for task in $FUNCTIONS; do SUMMARY+="  • $task\n"; done
    [[ -n "$NEW_USER" ]] && SUMMARY+="\nTARGET USER: $NEW_USER"

    if whiptail --title "FINAL CONFIRMATION" --yesno "$SUMMARY\n\nProceed with execution?" 22 70 3>&1 1>&2 2>&3; then
        execute_tasks
    else
        # Instead of "Modify", we just step back to the user flow
        user_management_flow
    fi
}

# ── EXECUTION ENGINE ──────────────────────────────────────────────────────────

run_task() {
    local task="$1"
    case $task in
        UPDATE)     source ./modules/system_update.sh     ;;
        REPOS)      source ./modules/repo_config.sh       ;;
        NAG)        source ./modules/disable_nag.sh       ;;
        USER)       source ./modules/user_setup.sh        ;;
        PASSWD)     source ./modules/sudo_nopasswd.sh     ;;
        CEPH)       source ./modules/ceph_setup.sh        ;;
        HA)         systemctl enable pve-ha-lrm pve-ha-crm &>/dev/null && msg_ok "ENABLED HA" ;;
        IOMMU)      source ./modules/hardware_config.sh   ;;
        VFIO)       source ./modules/vfio_config.sh       ;;
        ZFS)        source ./modules/zfs_tuning.sh        ;;
        SAMBA)      source ./modules/samba_setup.sh       ;;
        TUNING)     source ./modules/network_tuning.sh    ;;
        ESSENTIALS) source ./modules/essential_services.sh ;;
        HTOP)       apt-get install -y htop &>/dev/null   && msg_ok "INSTALLED HTOP" ;;
        TMUX)       source ./modules/tmux_setup.sh        ;;
        CURL)       apt-get install -y curl wget &>/dev/null && msg_ok "INSTALLED CURL/WGET" ;;
        GIT)        apt-get install -y git &>/dev/null    && msg_ok "INSTALLED GIT" ;;
        JQ)         apt-get install -y jq &>/dev/null     && msg_ok "INSTALLED JQ" ;;
        NET)        apt-get install -y net-tools &>/dev/null && msg_ok "INSTALLED NET-TOOLS" ;;
    esac
}

execute_tasks() {
    ERRORS=()
    for task in $FUNCTIONS; do
        echo -e "\n\e[36m▶ Running: $task\e[0m"
        if ! run_task "$task"; then
            echo -e "\e[31m✖ FAILED: $task\e[0m"
            ERRORS+=("$task")
        fi
    done

    # Completion Flag
    touch "/etc/proxmox-bootstrap.done"

    echo -e "\n\e[32m✔ BOOTSTRAP COMPLETE\e[0m"
    [[ ${#ERRORS[@]} -gt 0 ]] && echo -e "\e[31m  FAILED TASKS: ${ERRORS[*]}\e[0m"

    if whiptail --title "FINISHED" --yesno "Reboot now to apply changes?" 10 60; then
        reboot
    fi
}

# Start the flow
main_menu
