msg_ok "STARTING HARDWARE CONFIGURATION"
if ! lspci -nn | grep -iE "vga|3d|display" | grep -iq "nvidia\|amd\|ati"; then
    if ! whiptail --title "GPU NOT DETECTED" --yesno "NO DISCRETE GPU DETECTED. ENABLE IOMMU ANYWAY?" 10 60; then
        return
    fi
fi
CPU_VENDOR=$(lscpu | grep Vendor | awk '{print $3}')
[[ "$CPU_VENDOR" == "GenuineIntel" ]] && PARAM="intel_iommu=on" || PARAM="amd_iommu=on"
if [ -d "/sys/firmware/efi" ]; then
    msg_ok "UEFI DETECTED"
    [ -f "/etc/kernel/cmdline" ] && sed -i "s/$/ $PARAM iommu=pt/" /etc/kernel/cmdline
    proxmox-boot-tool refresh &>/dev/null
else
    msg_ok "BIOS DETECTED"
    sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$PARAM iommu=pt /" /etc/default/grub
    update-grub &>/dev/null
fi
cat <<VFIO > /etc/modules-load.d/vfio.conf
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
VFIO
update-initramfs -u &>/dev/null
