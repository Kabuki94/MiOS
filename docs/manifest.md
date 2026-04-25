# 📋 CloudWS-OS Feature Index

```json
{
  "status": "Verified",
  "data_source": "docs/PACKAGES.md"
}
```

---

## 📦 Core System

### 🧱 System Foundation
The immutable core is built for stability and cryptographic assurance.

```json
{
  "base": "Fedora Rawhide (fc45)",
  "package_manager": "DNF5",
  "init": "Systemd (PID 1)",
  "updater": "uupd (Staged delivery)"
}
```

### 🖥️ Desktop Ecosystem
Modern Wayland-only GNOME environment.

| Component | Standard |
| :--- | :--- |
| **Compositor** | `Mutter 50 (Wayland)` |
| **Toolkit** | `GTK 4.22` |
| **Typography** | `Geist (Vercel)` |
| **Theming** | `Adaptive Dark Mode` |

---

## 🛠️ Workstation Toolkit

### 🏗️ Development Sandboxes
Mutable environments within the immutable host.

{
    "sandboxing": {
      "engine": "Distrobox / Podman",
      "gui_forwarding": "Wayland socket mapping",
      "persistence": "Home directory integration"
    }
  }
}
```

---

## 🛠️ Toolchain Index

| Binary | Purpose | Path |
| :--- | :--- | :--- |
| **`cloudws`** | Master CLI entry point | `/usr/bin/cloudws` |
| **`cloudws-backup`** | State & persistent data backup | `/usr/bin/cloudws-backup` |
| **`cloudws-update`** | Staged bootc image transactions | `/usr/bin/cloudws-update` |
| **`cloudws-status`** | Real-time role & service telemetry | `/usr/bin/cloudws-status` |
| **`cloudws-vfio-check`** | IOMMU and passthrough diagnostics | `/usr/bin/cloudws-vfio-check` |
| **`cloudws-vfio-toggle`** | Dynamic GPU isolation (no-reboot) | `/usr/bin/cloudws-vfio-toggle` |
| **`cloudws-rebuild`** | In-place OS self-replication | `/usr/bin/cloudws-rebuild` |
| **`ujust`** | Unified Blue build & config recipes | `/usr/bin/ujust` |
| **`iommu-groups`** | Raw hardware isolation reporting | `/usr/bin/iommu-groups` |

---

