# 📋 CloudWS-OS Feature Manifest

```json
{
  "type": "Single Source of Truth (SSOT)",
  "v1.3.0_standard": "Verified",
  "data_source": "docs/PACKAGES.md"
}
```

---

## 📦 Core Component Matrix

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

```json
{
  "sandboxing": {
    "engine": "Distrobox / Podman",
    "gui_forwarding": "Wayland socket mapping",
    "persistence": "Home directory integration"
  }
}
```

---
