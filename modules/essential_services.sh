#!/usr/bin/env bash
apt-get install -y fail2ban chrony smartmontools &>/dev/null
systemctl enable fail2ban chrony smartd &>/dev/null
systemctl start fail2ban chrony smartd &>/dev/null
msg_ok "ESSENTIAL SERVICES INSTALLED & ENABLED"
