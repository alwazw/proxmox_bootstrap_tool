msg_ok "Configuring IOMMU (UEFI/BIOS Aware)"
CPU_VENDOR=$(lscpu | grep Vendor | awk '{print $3}')
[[ "$CPU_VENDOR" == "GenuineIntel" ]] && PARAM="intel_iommu=on" || PARAM="amd_iommu=on"

if [ -d "/sys/firmware/efi" ]; then
    # UEFI/systemd-boot
    if [ -f "/etc/kernel/cmdline" ]; then
        if ! grep -q "$PARAM" /etc/kernel/cmdline; then
            sed -i "s/$/ $PARAM iommu=pt/" /etc/kernel/cmdline
            proxmox-boot-tool refresh &>/dev/null
        fi
    fi
else
    # BIOS/GRUB
    if ! grep -q "$PARAM" /etc/default/grub; then
        sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$PARAM iommu=pt /" /etc/default/grub
        update-grub &>/dev/null
    fi
fi
