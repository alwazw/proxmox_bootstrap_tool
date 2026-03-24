# modules/repo_config.sh

msg_ok "MIGRATING TO DEB822 REPOSITORIES"

KEYRING="/etc/apt/keyrings/proxmox-release-trixie.gpg"
mkdir -p /etc/apt/keyrings

# Force re-download keyring
wget -q https://enterprise.proxmox.com/debian/proxmox-release-trixie.gpg -O "$KEYRING"

# Nuke ALL existing repo files (both formats) — handles community script leftovers
mkdir -p /root/pve_repo_backup
find /etc/apt/sources.list.d/ -name "*.list" -o -name "*.sources" \
  | xargs -I{} mv {} /root/pve_repo_backup/ 2>/dev/null || true

# Debian base (keep this clean)
cat <<REPOS > /etc/apt/sources.list
deb http://deb.debian.org/debian trixie main contrib
deb http://deb.debian.org/debian trixie-updates main contrib
deb http://security.debian.org/debian-security trixie-security main contrib
REPOS

# PVE no-subscription — component: pve-no-subscription
cat <<REPOS > /etc/apt/sources.list.d/pve-no-sub.sources
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: $KEYRING
REPOS

# Ceph Squid — component: no-subscription (NOT main)
cat <<REPOS > /etc/apt/sources.list.d/ceph-squid.sources
Types: deb
URIs: http://download.proxmox.com/debian/ceph-squid
Suites: trixie
Components: no-subscription
Signed-By: $KEYRING
REPOS

apt-get update
