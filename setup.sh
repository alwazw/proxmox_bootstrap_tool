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
            git clone -q "$REPO_URL" "$TMP_DIR" || (wget -qO- "$REPO_URL/archive/refs/heads/main.tar.gz" | tar xz -C "$TMP_DIR" --strip-components=1)
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

# Parse arguments
SKIP_CHECKS=false
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --skip-checks)
            SKIP_CHECKS=true
            ;;
        -h|--help)
            echo "Usage: $0 [--skip-checks]"
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            echo "Usage: $0 [--skip-checks]" >&2
            exit 1
            ;;
    esac
    shift
done

check_dependencies
check_root "$SKIP_CHECKS"
check_cluster "$SKIP_CHECKS"

BOOTSTRAP_FLAG="/etc/proxmox-bootstrap.done"
if [ -f "$BOOTSTRAP_FLAG" ]; then
    echo -e "\e[32m✔ Bootstrap already completed previously. Exiting.\e[0m"
    exit 0
fi

trap "rm -f /tmp/pve_mode /tmp/pve_choices" EXIT

CURRENT_STEP="MODE"
SETUP_MODE=""
FUNCTIONS=""

while true; do
    case "$CURRENT_STEP" in
        MODE)
            whiptail --title "PROXMOX VE 9 BOOTSTRAP TOOL" --radiolist \
            "\nSELECT SETUP MODE:" 15 65 2 \
            "FULL" "RUN FULL SETUP PROCESS (RECOMMENDED)" ON \
            "ADVANCED" "SELECT INDIVIDUAL COMPONENTS TO INSTALL" OFF \
            3>&1 1>&2 2>&3 > /tmp/pve_mode

            if [[ $? -ne 0 ]]; then exit 0; fi
            SETUP_MODE=$(cat /tmp/pve_mode)
            if [[ "$SETUP_MODE" == "FULL" ]]; then
                FUNCTIONS="REPOS UPDATE NAG USER PASSWD CEPH HA IOMMU VFIO ZFS SAMBA TUNING HTOP TMUX CURL GIT JQ NET ESSENTIALS"
                CURRENT_STEP="USER"
            else
                CURRENT_STEP="ADVANCED"
            fi
            ;;

        ADVANCED)
            # DIV items are selectable but we filter them. In UI they are just separators.
            whiptail --title "ADVANCED CONFIGURATION" --checklist \
            $'\nSELECT TASKS TO PERFORM (SPACE TO SELECT):' 22 75 14 \
            "DIV1"   "─── CONFIGURATION ──────────────────" OFF \
            "USER"   "CREATE PRIVILEGED SUDO USER"          OFF \
            "PASSWD" "SET SUDO TO NOPASSWD"                 OFF \
            "NAG"    "DISABLE SUBSCRIPTION NAG"             OFF \
            "REPOS"  "TRIXIE MODERN SOURCE FILES (DEB822)"  OFF \
            "CEPH"   "CONFIGURE CEPH REPO & INSTALL"        OFF \
            "HA"     "ENABLE HA SERVICES"                   OFF \
            "DIV2"   "─── HARDWARE & STORAGE ─────────────" OFF \
            "IOMMU"  "HARDWARE PASSTHROUGH (GPU CHECK)"     OFF \
            "VFIO"   "LOAD VFIO MODULES"                    OFF \
            "ZFS"    "ZFS TUNE & MONTHLY SCRUB"             OFF \
            "SAMBA"  "SAMBA INSTALL & CIFS MOUNT"           OFF \
            "TUNING" "NETWORK MAX SOCKET BUFFERS"           OFF \
            "DIV3"   "─── UPDATES & TOOLS ────────────────" OFF \
            "UPDATE" "SYSTEM UPDATE & UPGRADE"              OFF \
            "ESSENTIALS" "FAIL2BAN, CHRONY, SMARTD"         OFF \
            "TMUX"   "INSTALL TMUX & AUTO-START BASHRC"     OFF \
            "HTOP"   "INSTALL HTOP"                         OFF \
            "CURL"   "INSTALL CURL & WGET"                  OFF \
            "GIT"    "INSTALL GIT"                          OFF \
            "JQ"     "INSTALL JQ"                           OFF \
            "NET"    "INSTALL NET-TOOLS (IFCONFIG/IP)"      OFF \
            --ok-button "Next" --cancel-button "Back" \
            3>&1 1>&2 2>&3 > /tmp/pve_choices

            STATUS=$?
            if [[ $STATUS -eq 1 ]]; then CURRENT_STEP="MODE"; continue; fi
            if [[ $STATUS -ne 0 ]]; then exit 0; fi

            CHOICES=$(cat /tmp/pve_choices | tr -d '"')
            FUNCTIONS=$(echo "$CHOICES" | sed -e 's/DIV[1-3]//g' | xargs)
            if [[ -z "$FUNCTIONS" ]]; then
                whiptail --msgbox "No tasks selected." 10 40
                continue
            fi

            if [[ "$FUNCTIONS" == *"USER"* ]]; then
                CURRENT_STEP="USER"
            else
                USER_ACTION="SKIP"
                CURRENT_STEP="SUMMARY"
            fi
            ;;

        USER)
            get_user_credentials
            STATUS=$?
            if [[ $STATUS -eq 5 ]]; then continue; fi # RE-RUN USER STEP (INTERNAL LOOP)
            if [[ $STATUS -eq 1 ]]; then # BACK
                if [[ "$SETUP_MODE" == "FULL" ]]; then CURRENT_STEP="MODE"; else CURRENT_STEP="ADVANCED"; fi
                continue
            elif [[ $STATUS -eq 3 ]]; then # SKIP
                USER_ACTION="SKIP"
                CURRENT_STEP="SUMMARY"
            elif [[ $STATUS -eq 0 ]]; then # SUCCESS
                CURRENT_STEP="SUMMARY"
            else
                exit 0
            fi
            ;;

        SUMMARY)
            SUMMARY="THE FOLLOWING TASKS WILL BE PERFORMED:\n\n"
            for task in $FUNCTIONS; do
                if [[ "$task" == "USER" || "$task" == "PASSWD" ]]; then
                    [[ "$USER_ACTION" == "SKIP" ]] && continue
                fi
                SUMMARY+="  • $task\n"
            done
            [[ "$USER_ACTION" != "SKIP" && -n "$NEW_USER" ]] && SUMMARY+="\nUSER: $NEW_USER (ACTION: $USER_ACTION)"

            if whiptail --title "FINAL CONFIRMATION" --yes-button "PROCEED" --no-button "BACK" --yesno "$SUMMARY\n\nPROCEED WITH EXECUTION?" 20 70; then
                break
            else
                if [[ "$FUNCTIONS" == *"USER"* ]]; then CURRENT_STEP="USER"; else CURRENT_STEP="ADVANCED"; fi
            fi
            ;;
    esac
done

# ── Task Execution ───────────────────────────────────────────────────────────
ERRORS=()
run_task() {
    local task="$1"
    case $task in
        UPDATE) source ./modules/system_update.sh && return 0 || return 1 ;;
        REPOS)  source ./modules/repo_config.sh && return 0 || return 1 ;;
        NAG)    source ./modules/disable_nag.sh && return 0 || return 1 ;;
        USER)   source ./modules/user_setup.sh && return 0 || return 1 ;;
        PASSWD) source ./modules/sudo_nopasswd.sh && return 0 || return 1 ;;
        CEPH)   source ./modules/ceph_setup.sh && return 0 || return 1 ;;
        HA)     systemctl enable pve-ha-lrm pve-ha-crm &>/dev/null && msg_ok "ENABLED HA" && return 0 || return 1 ;;
        IOMMU)  source ./modules/hardware_config.sh && return 0 || return 1 ;;
        VFIO)   source ./modules/vfio_config.sh && return 0 || return 1 ;;
        ZFS)    source ./modules/zfs_tuning.sh && return 0 || return 1 ;;
        SAMBA)  source ./modules/samba_setup.sh && return 0 || return 1 ;;
        TUNING) source ./modules/network_tuning.sh && return 0 || return 1 ;;
        ESSENTIALS) source ./modules/essential_services.sh && return 0 || return 1 ;;
        HTOP)   apt-get install -y htop &>/dev/null && msg_ok "INSTALLED HTOP" && return 0 || return 1 ;;
        TMUX)   source ./modules/tmux_setup.sh && return 0 || return 1 ;;
        CURL)   apt-get install -y curl wget &>/dev/null && msg_ok "INSTALLED CURL & WGET" && return 0 || return 1 ;;
        GIT)    apt-get install -y git &>/dev/null && msg_ok "INSTALLED GIT" && return 0 || return 1 ;;
        JQ)     apt-get install -y jq &>/dev/null && msg_ok "INSTALLED JQ" && return 0 || return 1 ;;
        NET)    apt-get install -y net-tools &>/dev/null && msg_ok "INSTALLED NET-TOOLS" && return 0 || return 1 ;;
    esac
}

for task in $FUNCTIONS; do
    if [[ "$task" == "USER" || "$task" == "PASSWD" ]]; then
        [[ "$USER_ACTION" == "SKIP" ]] && continue
    fi
    echo -e "\n\e[36m▶ Running: $task\e[0m"
    if ! run_task "$task"; then
        echo -e "\e[31m✖ FAILED: $task\e[0m"
        ERRORS+=("$task")
    fi
done

touch $BOOTSTRAP_FLAG
echo -e "\n\e[32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e "\e[32m  BOOTSTRAP COMPLETE\e[0m"
echo -e "\e[32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
[[ ${#ERRORS[@]} -gt 0 ]] && echo -e "\e[31m  FAILED TASKS: ${ERRORS[*]}\e[0m"

if whiptail --title "BOOTSTRAP COMPLETE" --yes-button "REBOOT NOW" --no-button "REBOOT LATER" --yesno "SETUP FINISHED.\n\nREBOOT NOW?" 12 65; then
    reboot
fi
