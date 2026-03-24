apt-get install -y tmux &>/dev/null
if ! grep -q "tmux attach" /root/.bashrc; then
cat <<TMUX >> /root/.bashrc
 if [ -f ~/.bashrc ]; then
     . ~/.bashrc
 fi
fi
msg_ok "TMUX CONFIGURED"
