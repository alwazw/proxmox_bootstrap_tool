msg_ok "VALIDATING REPOSITORY CONFIGURATION"

# Safety Gate
if [[ "$SKIP_CHECKS" != "true" ]]; then
    if ! whiptail --title "Repository Reset" --yesno "This will backup and RESET your APT sources to official Proxmox/Debian DEB822 defaults.\n\nCustom third-party repositories in /etc/apt/sources.list.d/ will be moved to backup.\n\nProceed with full reset?" 12 70; then
        echo -e "\e[33m⚠ Repository reset skipped by user.\e[0m"
        return 0
    fi
fi

# Backup and clear old lists
if [ -f "/etc/apt/sources.list" ]; then
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
fi

mkdir -p /root/pve_repo_backup
# Target known/suspect files while allowing user to move all if they agreed above
# The gate above ensures the user is aware of the "nuke" behavior.
find /etc/apt/sources.list.d/ -name "*.list" -o -name "*.sources" \
  | xargs -I{} mv {} /root/pve_repo_backup/ 2>/dev/null || true

# Debian Base (Official Recommended)
cat <<REPOS > /etc/apt/sources.list.d/debian.sources
Types: deb deb-src
URIs: http://deb.debian.org/debian/
Suites: trixie trixie-updates
Components: main non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: http://security.debian.org/debian-security/
Suites: trixie-security
Components: main non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
REPOS

# Keyring management (Official Path)
KEYRING="/usr/share/keyrings/proxmox-archive-keyring.gpg"
mkdir -p /usr/share/keyrings
wget -q https://enterprise.proxmox.com/debian/proxmox-archive-keyring-trixie.gpg -O "$KEYRING"

# PVE no-subscription
cat <<REPOS > /etc/apt/sources.list.d/proxmox.sources
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: $KEYRING
REPOS

# Ceph Squid
cat <<REPOS > /etc/apt/sources.list.d/ceph.sources
Types: deb
URIs: http://download.proxmox.com/debian/ceph-squid
Suites: trixie
Components: no-subscription
Signed-By: $KEYRING
REPOS

# Empty main sources.list to avoid duplication
echo "# Repositories are managed in /etc/apt/sources.list.d/" > /etc/apt/sources.list

# Refresh
if apt-get update &>/dev/null; then
    msg_ok "APT CONFIGURATION REPAIRED & UPDATED (OFFICIAL DEB822)"
else
    echo -e "\e[31m✖ FAILED TO UPDATE APT. Please check network or manual configuration.\e[0m"
    return 1
fi
