# 🌐 MiOS — Cloud Native Operating System
> **Proprietor:** Kabu.ki
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to Kabu.ki
> **Source Reference:** MiOS-Core-v2.1.0
---

# 🛡️ WSL2 Deployment & Security Guide

This document outlines the requirements and security considerations for deploying MiOS as a WSL2 distribution.

## 🚨 SECURITY ADVISORY: CVE-2026-32178

A critical vulnerability (**CVE-2026-32178**) affecting the .NET runtime used in the WSL host has been identified. This vulnerability allows for SMTP header injection via `System.Net.Mail`.

### 🛠️ Required Mitigation
To ensure the security of your MiOS deployment on Windows, you **MUST** upgrade your WSL host to version **2.1.0 or higher**.

**Check your version:**
```powershell
wsl --version
```

**Upgrade command:**
```powershell
wsl --update
```

---

## 🚀 Deployment Workflow

MiOS is optimized for WSL2 through a specialized synthesis process that generates a compatible rootfs tarball.

### 1. Generate WSL Artifact
Use the root `Justfile` to synthesize the WSL tarball:
```bash
just wsl
```
This generates `artifacts/mios-wsl.tar`.

### 2. Import into Windows
On your Windows host, import the tarball as a new distribution:
```powershell
wsl --import MiOS C:\WSL\MiOS .\artifacts\mios-wsl.tar
```

### 3. Initialize
Launch MiOS and follow the first-boot initialization prompts:
```powershell
wsl -d MiOS
```

---

## 🔧 WSL2 Optimization

### Memory & CPU Scaling
MiOS automatically requests optimal resources in WSL2. You can further customize this in your `%USERPROFILE%\.wslconfig`:

```ini
[wsl2]
memory=16GB
processors=8
```

### Podman Integration
MiOS in WSL2 is pre-configured to handle Podman-native workloads. The `mios-builder` machine logic in `cloud-ws.ps1` ensures that build-time isolation is maintained even when running inside a Windows host.

---
### ⚖️ Legal & Source Reference
- **Copyright:** (c) 2026 Kabu.ki
- **Status:** Personal Property / Private Infrastructure
- **Project Repository:** [Kabuki94/mios](https://github.com/Kabuki94/mios)
- **Documentation:** [MiOS Knowledge Base](https://github.com/Kabuki94/mios/tree/main/docs/knowledge)
- **Artifact Hub:** [ai-context.json](../../ai-context.json)
---
