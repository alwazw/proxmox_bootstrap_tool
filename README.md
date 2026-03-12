# Proxmox VE 9 Node Bootstrap Framework

> A modular, TUI-driven automation framework for standardizing the deployment and optimization of Proxmox VE 9 (Trixie) nodes — engineered to align with SRE workflows and replace deprecated monolithic scripts with a scalable, maintainable solution.

---

## 🚀 Quick Deploy

Run the following command directly in your Proxmox shell to launch the TUI installer. Recommended for fresh Proxmox 9.x installations.

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/alwazw/proxmox_bootstrap_tool/main/setup.sh)"
```

---

## 🛠 Engineering Principles

### 1. Hybrid Bootloader Abstraction (UEFI vs. BIOS)

The framework includes intelligent boot environment detection to ensure architectural compatibility across modern and legacy hardware:

- **UEFI / systemd-boot** — Detects `/sys/firmware/efi` and a ZFS-on-Root configuration, then automates kernel parameter injection via `proxmox-boot-tool refresh`.
- **Legacy BIOS / GRUB** — Falls back to `/etc/default/grub` orchestration with `update-grub` execution hooks when EFI firmware is absent.

### 2. DEB822 Repository Standardization

Proxmox 9 adopts the DEB822 multi-line specification for package management. This framework automates migration from legacy `.list` files to modern `.sources` stanzas:

| Objective | Implementation |
|---|---|
| **System Idempotency** | Prevents redundant entries and configuration drift |
| **Optimized Mirrors** | Precise selection of No-Subscription and Ceph-Squid repositories |
| **Cryptographic Security** | GPG keyring management under `/etc/apt/keyrings/` per current best practices |

### 3. Modular Architecture

The framework is structured into discrete, decoupled logic components for extensibility:

```
proxmox_bootstrap_tool/
├── lib/            # Shared hardware abstraction layers & UI helper functions
├── modules/        # Decoupled task logic (IOMMU passthrough, microcode updates, user provisioning)
└── setup.sh        # Primary orchestrator — manages whiptail interface lifecycle & process flow
```

---

## 📦 Manual Installation

For environments requiring local inspection or manual control:

```bash
git clone https://github.com/alwazw/proxmox_bootstrap_tool
cd proxmox_bootstrap_tool
chmod +x setup.sh
./setup.sh
```

---

## 📅 Roadmap

Active development is underway to evolve this tool into a comprehensive Infrastructure-as-Code (IaC) enabler.

- [ ] **Ansible Orchestration Module** — Dynamic inventory generator and playbooks for large-scale cluster management
- [ ] **Terraform & OpenTofu Integration** — Declarative VM deployment via API user provisioning and RBAC automation
- [ ] **Security Hardening (CIS Compliance)** — SSH key-based auth enforcement and `fail2ban` integration for the Proxmox admin interface
- [ ] **Automated Cluster Convergence** — Streamlined node integration into existing clusters via secure API token authentication

---

## 🤝 Contributing

Contributions that enhance SRE operational efficiency or expand hardware compatibility are welcome. Please adhere to the abstraction patterns established in the `lib/` directory when submitting pull requests.
