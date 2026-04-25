# 🛡️ CloudWS-OS Security Guide

```json
{
  "setup": "Zero-Trust Enforcement",
  "frameworks": ["fapolicyd", "USBGuard", "CrowdSec", "fs-verity"],
  "standard": "Immutable OCI"
}
```

---

## 🔒 Hardened Layers

### 🧠 Execution Control
CloudWS-OS implements strict binary whitelisting to prevent unauthorized execution.

```json
{
  "whitelisting": {
    "engine": "fapolicyd",
    "policy": "deny-by-default",
    "exceptions": ["/usr/bin", "/usr/lib", "/usr/local/bin"]
  }
}
```

### ⚡ Cryptographic Integrity
The core system is sealed using `composefs` and the Linux kernel's `fs-verity` subsystem.

1. **Seal:** Root partition is hashed during build.
2. **Audit:** `cloudws-verify` checks signatures early in the initramfs boot phase.
3. **Recovery:** Immediate autonomous rollback to fallback deployment on verification failure.

---

## 🔌 Physical Security

### ⌨️ Peripheral Gating
USBGuard intercepts unauthorized devices at the kernel level.

| Device Type | Policy | Implementation |
| :--- | :--- | :--- |
| **Connected at Boot** | `Allow` | Implicit trust of pre-existing hardware |
| **New Inseration** | `Block` | Requires `usbguard allow-device` |
| **HID Emulators** | `Deny` | Instant detection and lockout |

---

## 🌐 Network Defense
Firewalld is configured for maximum isolation.

```json
{
  "firewall": {
    "default_zone": "drop",
    "active_ips": "CrowdSec sovereign engine",
    "whitelisted_interfaces": ["lo", "podman0", "virbr0"]
  }
}
```

---
