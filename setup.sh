#!/usr/bin/env bash
source ./lib/sys_checks.sh
source ./lib/ui_helpers.sh

check_root
check_cluster

# Main Selection Menu
FUNCTIONS=$(whiptail --title "Proxmox VE 9 Bootstrap Tool" --checklist \
"Select tasks to perform (Space to select):" 20 75 10 \
"UPDATE" "System Update & Essential Tools" ON \
"REPOS" "Configure No-Subscription DEB822 Repos" ON \
"USER" "Create Privileged Sudo User" OFF \
"IOMMU" "Hardware Passthrough (UEFI Aware)" OFF \
"TUNING" "ZFS & Network Optimizations" ON 3>&1 1>&2 2>&3)

exitstatus=$?
if [ $exitstatus != 0 ]; then echo "Exit."; exit; fi

# Contextual Prompts
[[ $FUNCTIONS == *"USER"* ]] && get_user_credentials

# Summary / Dry Run Logic
SUMMARY="The following modules will run:\n${FUNCTIONS//\"/}\n"
[[ $FUNCTIONS == *"USER"* ]] && SUMMARY+="\nUser to create: $NEW_USER"

if whiptail --title "Confirm Execution" --yesno "$SUMMARY\n\nProceed?" 15 60; then
    for task in $FUNCTIONS; do
        case $task in
            "\"UPDATE\"") source ./modules/system_update.sh ;;
            "\"REPOS\"")  source ./modules/repo_config.sh ;;
            "\"USER\"")   source ./modules/user_setup.sh ;;
            "\"IOMMU\"")  source ./modules/hardware_config.sh ;;
            "\"TUNING\"") source ./modules/optimizations.sh ;;
        esac
    done
    whiptail --title "Complete" --msgbox "Bootstrap finished! Reboot is recommended." 10 60
else
    echo "Cancelled."
fi
