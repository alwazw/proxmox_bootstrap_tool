msg_ok "MIGRATING TO DEB822 REPOSITORIES"

KEYRING="/etc/apt/keyrings/proxmox-release-trixie.gpg"
mkdir -p /etc/apt/keyrings
wget -q https://enterprise.proxmox.com/debian/proxmox-release-trixie.gpg -O "$KEYRING"

# Backup AND remove both legacy .list and existing .sources files
mkdir -p /root/pve_repo_backup
mv /etc/apt/sources.list.d/*.list  /root/pve_repo_backup/ 2>/dev/null || true
mv /etc/apt/sources.list.d/*.sources /root/pve_repo_backup/ 2>/dev/null || true

# PVE no-subscription repo — correct component is 'pve-no-subscription'
cat <<REPOS > /etc/apt/sources.list.d/pve-no-sub.sources
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: $KEYRING
REPOS

# Ceph Squid repo — correct component is 'main'
cat <<REPOS > /etc/apt/sources.list.d/ceph-squid.sources
Types: deb
URIs: http://download.proxmox.com/debian/ceph-squid
Suites: trixie
Components: main
Signed-By: $KEYRING
REPOS

apt-get update &>/dev/null
