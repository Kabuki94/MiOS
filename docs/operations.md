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
