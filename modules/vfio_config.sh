cat <<EOF > /etc/modules-load.d/vfio.conf
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
EOF
update-initramfs -u &>/dev/null
msg_ok "VFIO MODULES LOADED"
