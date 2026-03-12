#!/usr/bin/env bash
echo "root ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/root-nopasswd
chmod 0440 /etc/sudoers.d/root-nopasswd
msg_ok "SUDO NOPASSWD CONFIGURED"
