# 🌐 CloudWS-bootc — Universal AI Integration
> **Proprietor:** Kabu.ki
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to Kabu.ki
---
# 🛠️ CloudWS-OS Operational Handbook

```json
{
  "scope": "System Administration & Deployment",
  "baseline": "v1.3.0",
  "tools": ["bootc", "just", "cloudws-backup", "cloudws-update"]
}
```

---

## 🚀 Deployment & Installation

### 💻 WSL2 Quickstart
CloudWS-OS is optimized for Windows Subsystem for Linux with automated pathing and systemd enablement.

```json
{
  "wsl_config": {
    "systemd": true,
    "networkingMode": "mirrored",
    "dnsTunneling": true,
    "memory": "75% of host"
  }
}
```

1. **Import:** `wsl --import CloudWS-OS C:\WSL\CloudWS output\cloudws-wsl.tar --version 2`
2. **Initialize:** First boot executes `cloudws-wsl-firstboot` to provision home directories and SSH keys.

---

## 🔄 Lifecycle Management

### 📥 System Upgrades
CloudWS-OS uses transactional atomic swaps.

| Method | Command | Behavior |
| :--- | :--- | :--- |
| **Immediate** | `sudo bootc upgrade` | Pulls and stages for next reboot |
| **Staged** | `sudo bootc upgrade --download-only` | Caches image for scheduled maintenance |
| **Rollback** | `sudo bootc rollback` | Reverts to previous deployment |

---

## 💾 Backup & Persistence

### 🛡️ Data Retention
Only `/var` and `/etc` contain mutable state. All other changes are lost on upgrade.

```json
{
  "backup_targets": [
    "/var/home",
    "/etc/cloudws",
    "/var/lib/libvirt",
    "/var/lib/rancher"
  ],
  "tool": "cloudws-backup"
}
```

**Run Backup:** `sudo cloudws-backup --full`
**Storage Path:** `/var/lib/cloudws/backups/`

---

---
### 📚 Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osbuild/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [Kabuki94/CloudWS-bootc](https://github.com/Kabuki94/CloudWS-bootc)
- **Sole Proprietor:** Kabu.ki
---
