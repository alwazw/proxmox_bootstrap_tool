# 🚀 Proxmox VE 9 Node Bootstrap Tool

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Proxmox: 9.x](https://img.shields.io/badge/Proxmox-9.x-orange.svg)](https://www.proxmox.com)

A modular, TUI-driven automation framework designed to standardize the deployment and optimization of Proxmox VE 9 nodes. This project demonstrates advanced Bash scripting, system architecture awareness, and hardware-specific automation.

---

## 🛠 Project Architecture

Unlike monolithic scripts common in the homelab community, this tool uses a **modular "Plugin" architecture**. This ensures maintainability and allows for easy expansion without risking core logic stability.

* **`setup.sh`**: The central orchestrator and TUI handler using `whiptail`.
* **`lib/`**: Hardware abstraction layers and UI helper functions.
* **`modules/`**: Decoupled task logic (Repo management, IOMMU, User Setup).



---

## 💡 Technical Deep Dives

### 1. Intelligent Bootloader Detection (UEFI vs. BIOS)
One of the most common failure points in Proxmox automation is kernel parameter application. This tool implements a logic gate to verify the boot environment:
* **UEFI Detection:** If `/sys/firmware/efi` is present, the script modifies `/etc/kernel/cmdline` and invokes `proxmox-boot-tool refresh`.
* **Legacy BIOS Detection:** If absent, it targets `/etc/default/grub` and executes `update-grub`.

This prevents "ghost configurations" where settings are applied to the wrong bootloader, ensuring GPU Passthrough (IOMMU) works on the first reboot.



### 2. DEB822 Repository Migration
Proxmox 9/Debian Trixie is moving toward the **DEB822** standard for package sources. This tool proactively:
1.  Backs up legacy `.list` files to `/root/pve_repo_backup`.
2.  Generates high-performance, combined `.sources` files.
3.  Ensures GPG keys are correctly placed in `/etc/apt/keyrings/` rather than the deprecated `/etc/apt/trusted.gpg`.

### 3. Secure Credential Handling
To avoid hardcoded secrets, the tool utilizes a `whiptail`-driven UI to capture user intent. It includes:
* Recursive password verification loops.
* Masked input for security.
* Automated `NOPASSWD` sudoer configuration for streamlined cluster administration.

---

## 🚀 Getting Started

### Prerequisites
* A fresh installation of Proxmox VE 9.
* Internet connectivity for package updates and GPG key retrieval.

### Installation & Execution
```bash
# Clone the repository
git clone https://github.com/alwazw/proxmox_bootstrap_tool
cd proxmox_bootstrap_tool

# Make the runner executable
chmod +x setup.sh

# Start the TUI installer
./setup.sh
