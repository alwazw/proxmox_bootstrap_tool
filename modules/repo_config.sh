msg_ok "REPAIRING & MIGRATING TO DEB822 REPOSITORIES"

# Backup and clear old lists
if [ -f "/etc/apt/sources.list" ]; then
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
    echo "# Original sources.list backed up to sources.list.bak" > /etc/apt/sources.list
fi

mkdir -p /root/pve_repo_backup
mv /etc/apt/sources.list.d/*.list /root/pve_repo_backup/ 2>/dev/null || true
rm -f /etc/apt/sources.list.d/*.sources

# Keyring management
KEYRING="/etc/apt/keyrings/proxmox-release-trixie.gpg"
mkdir -p /etc/apt/keyrings
wget -q https://enterprise.proxmox.com/debian/proxmox-release-trixie.gpg -O "$KEYRING"

# Write new sources
cat <<REPOS > /etc/apt/sources.list.d/pve.sources
Types: deb
URIs: http://download.proxmox.com/debian/pve http://download.proxmox.com/debian/ceph-squid
Suites: trixie
Components: pve-no-subscription no-subscription
Signed-By: $KEYRING
REPOS

# Refresh
if apt-get update &>/dev/null; then
    msg_ok "APT CONFIGURATION REPAIRED & UPDATED"
else
    echo -e "\e[31m✖ FAILED TO UPDATE APT. Please check network or manual configuration.\e[0m"
    return 1
fi
