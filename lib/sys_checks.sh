#!/usr/bin/env bash
check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        whiptail --title "Error" --msgbox "This script must be run as root." 10 60
        exit 1
    fi
}

check_cluster() {
    if [ -f "/etc/pve/corosync.conf" ]; then
        if ! whiptail --title "Cluster Awareness" --yesno "Node is part of a cluster. Repository changes should be handled carefully. Continue?" 10 70; then
            exit 0
        fi
    fi
}
