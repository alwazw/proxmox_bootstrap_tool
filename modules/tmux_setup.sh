apt-get install -y tmux &>/dev/null
if ! grep -q "tmux attach" /root/.bashrc; then
cat <<TMUX >> /root/.bashrc
 if command -v tmux &> /dev/null && [ -z "\$TMUX" ]; then
    tmux attach -t main || tmux new -s main
fi
TMUX
fi
msg_ok "TMUX CONFIGURED"
