#!/usr/bin/env bash
source ./lib/sys_checks.sh
source ./lib/ui_helpers.sh

check_root
check_cluster

BOOTSTRAP_FLAG="/etc/proxmox-bootstrap.done"

if [ -f "$BOOTSTRAP_FLAG" ]; then
    echo -e "\e[32m✔ Bootstrap already completed previously. Exiting to prevent duplication.\e[0m"
    exit 0
fi

# ── Temp file cleanup ────────────────────────────────────────────────────────
trap "rm -f /tmp/pve_mode /tmp/pve_choices" EXIT

# ── PAGE 1: Mode Selection (Radiolist) ───────────────────────────────────────
whiptail --title "PROXMOX VE 9 BOOTSTRAP TOOL" --radiolist \
"\nSELECT SETUP MODE:" 15 65 2 \
"FULL" "RUN FULL SETUP PROCESS (RECOMMENDED)" ON \
"ADVANCED" "SELECT INDIVIDUAL COMPONENTS TO INSTALL" OFF \
3>&1 1>&2 2>&3 | tee /tmp/pve_mode

MODE_STATUS=${PIPESTATUS[0]}
if [[ $MODE_STATUS -ne 0 ]]; then
    echo -e "\n\e[33m✖ Setup cancelled.\e[0m\n"
    exit 0
fi

SETUP_MODE=$(cat /tmp/pve_mode)

# ── Define the Master List of All Functions ──────────────────────────────────
ALL_FUNCTIONS="REPOS UPDATE NAG USER PASSWD CEPH HA IOMMU VFIO ZFS SAMBA TUNING HTOP TMUX CURL GIT JQ NET ESSENTIALS"

if [[ "$SETUP_MODE" == *"FULL"* ]]; then
    FUNCTIONS=$ALL_FUNCTIONS
else
    # ── PAGE 2: Advanced Selection (Checklist) ───────────────────────────────
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
    3>&1 1>&2 2>&3 | tee /tmp/pve_choices

    EXIT_STATUS=${PIPESTATUS[0]}
    if [[ $EXIT_STATUS -ne 0 ]]; then
        echo -e "\n\e[33m✖ Setup cancelled.\e[0m\n"
        exit 0
    fi

    # Parse and clean selections
    CHOICES=$(cat /tmp/pve_choices)
    CHOICES=$(echo "$CHOICES" | sed -e 's/"DIV[1-3]"//g' | tr -d '"')
    FUNCTIONS=$(echo $CHOICES | xargs)
fi

if [[ -z "$FUNCTIONS" ]]; then
    echo -e "\n\e[33m✖ No tasks selected. Exiting.\e[0m\n"
    exit 0
fi

# ── Contextual Prompts ───────────────────────────────────────────────────────
[[ $FUNCTIONS == *"USER"* ]] && get_user_credentials

# ── Confirmation Summary ─────────────────────────────────────────────────────
SUMMARY="THE FOLLOWING TASKS WILL BE PERFORMED:\n\n"
for task in $FUNCTIONS; do
    SUMMARY+="  • $task\n"
done
[[ -n "$NEW_USER" ]] && SUMMARY+="\nUSER: $NEW_USER (ACTION: $USER_ACTION)"

if ! whiptail --title "FINAL CONFIRMATION" --yesno "$SUMMARY\n\nPROCEED WITH EXECUTION?" 20 70 3>&1 1>&2 2>&3; then
    echo -e "\n\e[31m✖ Cancelled.\e[0m\n"
    exit 0
fi

# ── Task Execution ───────────────────────────────────────────────────────────
ERRORS=()

run_task() {
    local task="$1"
    case $task in
        UPDATE) source ./modules/system_update.sh ;;
        REPOS)  source ./modules/repo_config.sh ;;
        NAG)    source ./modules/disable_nag.sh ;;
        USER)   source ./modules/user_setup.sh ;;
        PASSWD) source ./modules/sudo_nopasswd.sh ;;
        CEPH)   source ./modules/ceph_setup.sh ;;
        HA)     systemctl enable pve-ha-lrm pve-ha-crm &>/dev/null && msg_ok "ENABLED HA" ;;
        IOMMU)  source ./modules/hardware_config.sh ;;
        VFIO)   source ./modules/vfio_config.sh ;;
        ZFS)    source ./modules/zfs_tuning.sh ;;
        SAMBA)  source ./modules/samba_setup.sh ;;
        TUNING) source ./modules/network_tuning.sh ;;
        ESSENTIALS) source ./modules/essential_services.sh ;;
        HTOP)   apt-get install -y htop  &>/dev/null && msg_ok "INSTALLED HTOP" ;;
        TMUX)   source ./modules/tmux_setup.sh ;;
        CURL)   apt-get install -y curl wget &>/dev/null && msg_ok "INSTALLED CURL & WGET" ;;
        GIT)    apt-get install -y git   &>/dev/null && msg_ok "INSTALLED GIT" ;;
        JQ)     apt-get install -y jq    &>/dev/null && msg_ok "INSTALLED JQ" ;;
        NET)    apt-get install -y net-tools &>/dev/null && msg_ok "INSTALLED NET-TOOLS" ;;
        *)      echo -e "\e[33m⚠ Unknown task: $task — skipping.\e[0m" ;;
    esac
}

for task in $FUNCTIONS; do
    echo -e "\n\e[36m▶ Running: $task\e[0m"
    if ! run_task "$task"; then
        echo -e "\e[31m✖ FAILED: $task\e[0m"
        ERRORS+=("$task")
    fi
done

# Mark complete
touch $BOOTSTRAP_FLAG

# ── Completion Report ────────────────────────────────────────────────────────
echo -e "\n\e[32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e "\e[32m  BOOTSTRAP COMPLETE\e[0m"
echo -e "\e[32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo -e "\e[31m  FAILED TASKS: ${ERRORS[*]}\e[0m"
fi

if whiptail --title "BOOTSTRAP COMPLETE" --yes-button "REBOOT NOW" --no-button "REBOOT LATER" --yesno "SETUP FINISHED.\n\nA REBOOT IS RECOMMENDED TO APPLY KERNEL CHANGES.\n\nREBOOT NOW?" 12 65 3>&1 1>&2 2>&3; then
    echo -e "\e[32m✔ Rebooting...\e[0m"
    reboot
else
    echo -e "\e[33m⚠ Reboot skipped. Run 'reboot' when ready.\e[0m\n"
fi
root@GPU:~/proxmox-bootstrap#
