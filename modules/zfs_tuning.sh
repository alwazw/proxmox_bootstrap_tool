if [ ! -f /etc/modprobe.d/zfs.conf ]; then
    echo "options zfs zfs_arc_max=8589934592" > /etc/modprobe.d/zfs.conf
fi
if ! grep -q "zpool scrub rpool" /etc/crontab; then
    echo "0 3 1 * * root zpool scrub rpool" >> /etc/crontab
fi
msg_ok "ZFS TUNED AND SCRUB CRON ADDED"
