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
    echo -e "\e[32m✔ Bootstrap already completed previously. Exiting to prevent duplication.\e[0m"
    exit 0
fi

trap "rm -f /tmp/pve_mode /tmp/pve_choices" EXIT

# ── PAGE 1: Mode Selection ────────────────────────────────────────────────────
whiptail --title "PROXMOX VE 9 BOOTSTRAP TOOL" --radiolist \
"\nSELECT SETUP MODE:" 15 65 2 \
"FULL"     "RUN FULL SETUP PROCESS (RECOMMENDED)"    ON  \
"ADVANCED" "SELECT INDIVIDUAL COMPONENTS TO INSTALL" OFF \
3>&1 1>&2 2>&3 | tee /tmp/pve_mode

MODE_STATUS=${PIPESTATUS[0]}
if [[ $MODE_STATUS -ne 0 ]]; then
    echo -e "\n\e[33m✖ Setup cancelled.\e[0m\n"
    exit 0
fi

SETUP_MODE=$(cat /tmp/pve_mode)

ALL_FUNCTIONS="REPOS UPDATE NAG USER PASSWD CEPH HA IOMMU VFIO ZFS SAMBA TUNING HTOP TMUX CURL GIT JQ NET ESSENTIALS"

USER_SKIPPED=false

if [[ "$SETUP_MODE" == *"FULL"* ]]; then
    FUNCTIONS=$ALL_FUNCTIONS
else
    # ── PAGE 2: Advanced Selection ────────────────────────────────────────────
    # DIV rows use a non-selectable visual trick:
    #   - tag starts with "---" so it's filtered out post-selection
    #   - description uses Unicode box-drawing for a visible separator
    #   - OFF by default and ignored even if accidentally toggled
    whiptail --title "ADVANCED CONFIGURATION" --checklist \
    $'\nSELECT TASKS TO PERFORM (SPACE TO SELECT):' 26 75 18 \
    "---1" "$(printf '\e[0m')  ── CONFIGURATION ─────────────────────────" OFF \
    "USER"     "  Create privileged sudo user"              ON  \
    "PASSWD"   "  Set sudo to NOPASSWD"                     ON  \
    "NAG"      "  Disable subscription nag"                 ON  \
    "REPOS"    "  Trixie modern source files (DEB822)"      ON  \
    "CEPH"     "  Configure Ceph repo & install"            ON  \
    "HA"       "  Enable HA services"                       ON  \
    "---2" "  ── HARDWARE & STORAGE ──────────────────────" OFF \
    "IOMMU"   "  Hardware passthrough (GPU check)"          ON  \
    "VFIO"    "  Load VFIO modules"                         ON  \
    "ZFS"     "  ZFS tune & monthly scrub"                  ON  \
    "SAMBA"   "  Samba install & CIFS mount"                ON  \
    "TUNING"  "  Network max socket buffers"                ON  \
    "---3" "  ── UPDATES & TOOLS ─────────────────────────" OFF \
    "UPDATE"     "  System update & upgrade"                ON  \
    "ESSENTIALS" "  Fail2ban, Chrony, Smartd"               ON  \
    "TMUX"    "  Install tmux & auto-start bashrc"          ON  \
    "HTOP"    "  Install htop"                              ON  \
    "CURL"    "  Install curl & wget"                       ON  \
    "GIT"     "  Install git"                               ON  \
    "JQ"      "  Install jq"                                ON  \
    "NET"     "  Install net-tools (ifconfig/ip)"           ON  \
    3>&1 1>&2 2>&3 | tee /tmp/pve_choices

    EXIT_STATUS=${PIPESTATUS[0]}
    if [[ $EXIT_STATUS -ne 0 ]]; then
        echo -e "\n\e[33m✖ Setup cancelled.\e[0m\n"
        exit 0
    fi

    # Strip DIV separators and clean up
    CHOICES=$(cat /tmp/pve_choices | sed -e 's/"---[0-9]"//g' | tr -d '"')
    FUNCTIONS=$(echo $CHOICES | xargs)
fi

if [[ -z "$FUNCTIONS" ]]; then
    echo -e "\n\e[33m✖ No tasks selected. Exiting.\e[0m\n"
    exit 0
fi

# ── Contextual Prompts ────────────────────────────────────────────────────────
if [[ $FUNCTIONS == *"USER"* ]]; then
    # get_user_credentials should set NEW_USER, NEW_PASS, USER_ACTION
    # It must also support returning a "skip" signal — set USER_SKIPPED=true if user clicks skip
    get_user_credentials
    if [[ "$USER_SKIPPED" == "true" ]]; then
        # Remove USER and PASSWD from the task list
        FUNCTIONS=$(echo "$FUNCTIONS" | tr ' ' '\n' | grep -v -E '^(USER|PASSWD)$' | tr '\n' ' ' | xargs)
    fi
fi

# ── Confirmation Summary ──────────────────────────────────────────────────────
SUMMARY="THE FOLLOWING TASKS WILL BE PERFORMED:\n\n"
for task in $FUNCTIONS; do
    SUMMARY+="  • $task\n"
done
[[ -n "$NEW_USER" && "$USER_SKIPPED" != "true" ]] && \
    SUMMARY+="\n  USER: $NEW_USER  (ACTION: $USER_ACTION)"

# Confirmation with Modify + Back + Exit options
while true; do
    CHOICE=$(whiptail --title "FINAL CONFIRMATION" \
        --menu "$SUMMARY\n\nPROCEED WITH EXECUTION?" 24 70 4 \
        "YES"    "Proceed — run all selected tasks" \
        "MODIFY" "Go back and modify selection" \
        "BACK"   "Return to main menu" \
        "EXIT"   "Exit setup" \
        3>&1 1>&2 2>&3)

    case $CHOICE in
        YES)    break ;;
        MODIFY) exec bash "$0" "$@" ;;  # restart for full re-selection
        BACK)   exec bash "$0" "$@" ;;
        *)      echo -e "\n\e[31m✖ Cancelled.\e[0m\n"; exit 0 ;;
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
        HA)         systemctl enable pve-ha-lrm pve-ha-crm &>/dev/null \
                        && msg_ok "ENABLED HA"            && return 0 || return 1 ;;
        IOMMU)      source ./modules/hardware_config.sh   && return 0 || return 1 ;;
        VFIO)       source ./modules/vfio_config.sh       && return 0 || return 1 ;;
        ZFS)        source ./modules/zfs_tuning.sh        && return 0 || return 1 ;;
        SAMBA)      source ./modules/samba_setup.sh       && return 0 || return 1 ;;
        TUNING)     source ./modules/network_tuning.sh    && return 0 || return 1 ;;
        ESSENTIALS) source ./modules/essential_services.sh && return 0 || return 1 ;;
        HTOP)       apt-get install -y htop &>/dev/null   && msg_ok "INSTALLED HTOP"         && return 0 || return 1 ;;
        TMUX)       source ./modules/tmux_setup.sh        && return 0 || return 1 ;;
        CURL)       apt-get install -y curl wget &>/dev/null && msg_ok "INSTALLED CURL & WGET" && return 0 || return 1 ;;
        GIT)        apt-get install -y git &>/dev/null    && msg_ok "INSTALLED GIT"           && return 0 || return 1 ;;
        JQ)         apt-get install -y jq &>/dev/null     && msg_ok "INSTALLED JQ"            && return 0 || return 1 ;;
        NET)        apt-get install -y net-tools &>/dev/null && msg_ok "INSTALLED NET-TOOLS"  && return 0 || return 1 ;;
        *)          echo -e "\e[33m⚠ Unknown task: $task — skipping.\e[0m" && return 0 ;;
    esac
}

for task in $FUNCTIONS; do
    echo -e "\n\e[36m▶ Running: $task\e[0m"
    if ! run_task "$task"; then
        echo -e "\e[31m✖ FAILED: $task\e[0m"
        ERRORS+=("$task")
    fi
done

touch $BOOTSTRAP_FLAG

# ── Completion Report ─────────────────────────────────────────────────────────
echo -e "\n\e[32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e "\e[32m  BOOTSTRAP COMPLETE\e[0m"
echo -e "\e[32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo -e "\e[31m  FAILED TASKS: ${ERRORS[*]}\e[0m"
fi

if whiptail --title "BOOTSTRAP COMPLETE" \
    --yes-button "REBOOT NOW" --no-button "REBOOT LATER" \
    --yesno "SETUP FINISHED.\n\nA REBOOT IS RECOMMENDED TO APPLY KERNEL CHANGES.\n\nREBOOT NOW?" \
    12 65 3>&1 1>&2 2>&3; then
    echo -e "\e[32m✔ Rebooting...\e[0m"
    reboot
else
    echo -e "\e[33m⚠ Reboot skipped. Run 'reboot' when ready.\e[0m\n"
fi
