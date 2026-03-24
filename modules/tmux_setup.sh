apt-get install -y tmux &>/dev/null

if ! grep -q "alias tm=" /root/.bashrc; then
cat <<'EOF' >> /root/.bashrc

# Easy tmux access (manual start only)
alias tm='tmux attach -t main || tmux new -s main'
EOF
fi

msg_ok "TMUX CONFIGURED"
