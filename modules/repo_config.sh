msg_ok "MIGRATING TO DEB822 REPOSITORIES"
KEYRING="/etc/apt/keyrings/proxmox-release-trixie.gpg"
mkdir -p /etc/apt/keyrings
wget -q https://enterprise.proxmox.com/debian/proxmox-release-trixie.gpg -O "$KEYRING"
mkdir -p /root/pve_repo_backup
mv /etc/apt/sources.list.d/*.list /root/pve_repo_backup/ 2>/dev/null || true
cat <<REPOS > /etc/apt/sources.list.d/pve.sources
Types: deb
URIs: http://download.proxmox.com/debian/pve http://download.proxmox.com/debian/ceph-squid
Suites: trixie
Components: pve-no-subscription no-subscription
Signed-By: $KEYRING
REPOS
apt-get update &>/dev/null
