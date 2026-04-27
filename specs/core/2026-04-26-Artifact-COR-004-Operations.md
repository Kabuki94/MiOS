<!-- 🌐 MiOS Artifact | Proprietor: Kabu.ki | https://github.com/kabuki94/mios -->
# 🌐 MiOS
```json:knowledge
{
  "summary": "> **Proprietor:** Kabu.ki",
  "logic_type": "documentation",
  "tags": [
    "MiOS",
    "core"
  ],
  "relations": {
    "depends_on": [
      ".env.mios"
    ],
    "impacts": []
  }
}
```
> **Proprietor:** Kabu.ki
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to Kabu.ki
> **Source Reference:** MiOS-Core-v0.1.1
---

# 🛠️ MiOS Operational Handbook

```json
{
  "scope": "System Administration & Deployment",
  "baseline": "v0.1.1",
  "tools": ["bootc", "just", "mios-backup", "mios-update"]
}
```

---

## 🚀 Deployment & Installation

### 💻 WSL2 Quickstart
MiOS is optimized for Windows Subsystem for Linux with automated pathing and systemd enablement.

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

1. **Import:** `wsl --import MiOS C:\WSL\MiOS output\mios-wsl.tar --version 2`
2. **Initialize:** First boot executes `mios-wsl-firstboot` to provision home directories and SSH keys.

---

## 🔄 Lifecycle Management

### 📥 System Upgrades
MiOS uses transactional atomic swaps.

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
    "/etc/mios",
    "/var/lib/libvirt",
    "/var/lib/rancher"
  ],
  "tool": "mios-backup"
}
```

**Run Backup:** `sudo mios-backup --full`
**Storage Path:** `/var/lib/mios/backups/`

---

---
### ⚖️ Legal & Source Reference
- **Copyright:** (c) 2026 Kabu.ki
- **Status:** Personal Property / Private Infrastructure
- **Project Repository:** [Kabuki94/mios](https://github.com/Kabuki94/mios)
- **Documentation:** [MiOS Navigation Hub](https://github.com/Kabuki94/mios/blob/main/specs/Home.md)
- **Artifact Hub:** [ai-context.json](https://github.com/Kabuki94/mios/blob/main/ai-context.json)
---
<!-- ⚖️ MiOS Proprietary Artifact | Copyright (c) 2026 Kabu.ki -->
