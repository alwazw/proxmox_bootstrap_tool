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

# Export UI helpers for sourced modules
export -f msg_ok

# Parse arguments
SKIP_CHECKS=false
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --skip-checks) SKIP_CHECKS=true ;;
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
USER_ACTION="SKIP"

# ANSI color for dividers
DIV_TITLE=$(printf "\e[1;37m") # Bold White
RESET=$(printf "\e[0m")

while true; do
    case "$CURRENT_STEP" in
        MODE)
            whiptail --title "PROXMOX VE 9 BOOTSTRAP TOOL" --radiolist \
            "\nSELECT SETUP MODE:" 15 65 2 \
            "FULL"     "RUN FULL SETUP PROCESS (RECOMMENDED)" ON \
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
            whiptail --title "ADVANCED CONFIGURATION" --checklist \
            $'\nSELECT TASKS TO PERFORM (SPACE TO SELECT):' 26 75 18 \
            "---1" "${DIV_TITLE}── CONFIGURATION ─────────────────────────${RESET}" OFF \
            " "        " "                                             OFF \
            "USER"     "  Create privileged sudo user"              ON  \
            "PASSWD"   "  Set sudo to NOPASSWD"                     ON  \
            "NAG"      "  Disable subscription nag"                 ON  \
            "REPOS"    "  Trixie modern source files (DEB822)"      ON  \
            "CEPH"     "  Configure Ceph repo & install"            ON  \
            "HA"       "  Enable HA services"                       ON  \
            "---2" "${DIV_TITLE}── HARDWARE & STORAGE ──────────────────────${RESET}" OFF \
            "  "       " "                                             OFF \
            "IOMMU"   "  Hardware passthrough (GPU check)"          ON  \
            "VFIO"    "  Load VFIO modules"                         ON  \
            "ZFS"     "  ZFS tune & monthly scrub"                  ON  \
            "SAMBA"   "  Samba install & CIFS mount"                ON  \
            "TUNING"  "  Network max socket buffers"                ON  \
            "---3" "${DIV_TITLE}── UPDATES & TOOLS ─────────────────────────${RESET}" OFF \
            "   "      " "                                             OFF \
            "UPDATE"     "  System update & upgrade"                ON  \
            "ESSENTIALS" "  Fail2ban, Chrony, Smartd"               ON  \
            "TMUX"    "  Install tmux & auto-start bashrc"          ON  \
            "HTOP"    "  Install htop"                              ON  \
            "CURL"    "  Install curl & wget"                       ON  \
            "GIT"     "  Install git"                               ON  \
            "JQ"      "  Install jq"                                ON  \
            "NET"     "  Install net-tools (ifconfig/ip)"           ON  \
            --ok-button "Next" --cancel-button "Back" \
            3>&1 1>&2 2>&3 > /tmp/pve_choices

            STATUS=$?
            if [[ $STATUS -eq 1 ]]; then CURRENT_STEP="MODE"; continue; fi
            if [[ $STATUS -ne 0 ]]; then exit 0; fi

            CHOICES=$(cat /tmp/pve_choices | sed -e 's/"---[0-9]"//g' -e 's/" "//g' -e 's/"  "//g' -e 's/"   "//g' | tr -d '"')
            FUNCTIONS=$(echo "$CHOICES" | xargs)
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

            OPT=$(whiptail --title "FINAL CONFIRMATION" \
                --menu "$SUMMARY\n\nPROCEED WITH EXECUTION?" 24 70 4 \
                "YES"    "Proceed — run all selected tasks" \
                "MODIFY" "Modify selected components" \
                "BACK"   "Return to previous step" \
                "EXIT"   "Exit setup" \
                3>&1 1>&2 2>&3)

            case $OPT in
                YES)    break ;;
                MODIFY) if [[ "$SETUP_MODE" == "FULL" ]]; then CURRENT_STEP="MODE"; else CURRENT_STEP="ADVANCED"; fi ;;
                BACK)   if [[ "$FUNCTIONS" == *"USER"* ]]; then CURRENT_STEP="USER"; else CURRENT_STEP="ADVANCED"; fi ;;
                *)      exit 0 ;;
            esac
            ;;
    esac
done

# ── Task Execution ────────────────────────────────────────────────────────────
ERRORS=()
run_task() {
    local task="$1"
    case $task in
        UPDATE)     source ./modules/system_update.sh     && return 0 || return 1 ;;
        REPOS)      source ./modules/repo_config.sh       && return 0 || return 1 ;;
        NAG)        source ./modules/disable_nag.sh       && return 0 || return 1 ;;
        USER)       source ./modules/user_setup.sh        && return 0 || return 1 ;;
        PASSWD)     source ./modules/sudo_nopasswd.sh     && return 0 || return 1 ;;
        CEPH)       source ./modules/ceph_setup.sh        && return 0 || return 1 ;;
        HA)         systemctl enable pve-ha-lrm pve-ha-crm &>/dev/null && msg_ok "ENABLED HA" && return 0 || return 1 ;;
        IOMMU)      source ./modules/hardware_config.sh   && return 0 || return 1 ;;
        VFIO)       source ./modules/vfio_config.sh       && return 0 || return 1 ;;
        ZFS)        source ./modules/zfs_tuning.sh        && return 0 || return 1 ;;
        SAMBA)      source ./modules/samba_setup.sh       && return 0 || return 1 ;;
        TUNING)     source ./modules/network_tuning.sh    && return 0 || return 1 ;;
        ESSENTIALS) source ./modules/essential_services.sh && return 0 || return 1 ;;
        HTOP)       apt-get install -y htop &>/dev/null   && msg_ok "INSTALLED HTOP" && return 0 || return 1 ;;
        TMUX)       source ./modules/tmux_setup.sh        && return 0 || return 1 ;;
        CURL)       apt-get install -y curl wget &>/dev/null && msg_ok "INSTALLED CURL & WGET" && return 0 || return 1 ;;
        GIT)        apt-get install -y git &>/dev/null    && msg_ok "INSTALLED GIT" && return 0 || return 1 ;;
        JQ)         apt-get install -y jq &>/dev/null     && msg_ok "INSTALLED JQ" && return 0 || return 1 ;;
        NET)        apt-get install -y net-tools &>/dev/null && msg_ok "INSTALLED NET-TOOLS" && return 0 || return 1 ;;
        *)          echo -e "\e[33m⚠ Unknown task: $task — skipping.\e[0m" && return 0 ;;
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

# Mark complete only if no errors occurred
if [[ ${#ERRORS[@]} -eq 0 ]]; then
    touch "$BOOTSTRAP_FLAG"
fi

# ── Completion Report ─────────────────────────────────────────────────────────
echo -e "\n\e[32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e "\e[32m  BOOTSTRAP COMPLETE\e[0m"
echo -e "\e[32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
[[ ${#ERRORS[@]} -gt 0 ]] && echo -e "\e[31m  FAILED TASKS: ${ERRORS[*]}\e[0m"

if whiptail --title "BOOTSTRAP COMPLETE" --yes-button "REBOOT NOW" --no-button "REBOOT LATER" --yesno "SETUP FINISHED.\n\nA REBOOT IS RECOMMENDED TO APPLY KERNEL CHANGES.\n\nREBOOT NOW?" 12 65; then
    echo -e "\e[32m✔ Rebooting...\e[0m"
    reboot
fi
