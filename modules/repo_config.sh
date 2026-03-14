msg_ok "REPAIRING & MIGRATING TO DEB822 REPOSITORIES"

# Backup and clear old lists
if [ -f "/etc/apt/sources.list" ]; then
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
fi

mkdir -p /root/pve_repo_backup
# Nuke ALL existing repo files (both formats) — handles community script leftovers
find /etc/apt/sources.list.d/ -name "*.list" -o -name "*.sources" \
  | xargs -I{} mv {} /root/pve_repo_backup/ 2>/dev/null || true

# Write fresh Debian base
cat <<REPOS > /etc/apt/sources.list
deb http://deb.debian.org/debian trixie main contrib
deb http://deb.debian.org/debian trixie-updates main contrib
deb http://security.debian.org/debian-security trixie-security main contrib
REPOS

# Keyring management
KEYRING="/etc/apt/keyrings/proxmox-release-trixie.gpg"
mkdir -p /etc/apt/keyrings
wget -q https://enterprise.proxmox.com/debian/proxmox-release-trixie.gpg -O "$KEYRING"

# PVE no-subscription
cat <<REPOS > /etc/apt/sources.list.d/pve-no-sub.sources
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: $KEYRING
REPOS

# Ceph Squid
cat <<REPOS > /etc/apt/sources.list.d/ceph-squid.sources
Types: deb
URIs: http://download.proxmox.com/debian/ceph-squid
Suites: trixie
Components: no-subscription
Signed-By: $KEYRING
REPOS

# Refresh
if apt-get update &>/dev/null; then
    msg_ok "APT CONFIGURATION REPAIRED & UPDATED"
else
    echo -e "\e[31m✖ FAILED TO UPDATE APT. Please check network or manual configuration.\e[0m"
    return 1
fi
