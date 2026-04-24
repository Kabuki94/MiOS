# 🌐 AI-AGENT GLOBAL ENVIRONMENT & COORDINATION (AI-ENV)

> **MANDATORY READING FOR ALL AGENTS (CLAUDE, GEMINI, COPILOT)**
> This file tracks the live architectural baseline and environment-specific state.
> Update this file immediately upon implementing any cross-cutting change.

---

## 🛠️ CORE BASELINE ARGUMENTS

| VARIABLE | CURRENT VALUE | DESCRIPTION |
| :--- | :--- | :--- |
| `AI_ARCH_BASELINE` | **v0.1.8** | Current synchronized engineering baseline. |
| `AI_DNF_POLICY` | `"${DNF_SETOPT[@]}"` | Mandatory array usage for all package installs. |
| `AI_WSL_GATING` | `ConditionVirtualization=!wsl` | Standard for all service gating in WSL2. |
| `AI_OVERLAY_PATH` | `system_files/` | The ONLY directory for persistent system config. |
| `AI_PKG_SOURCE` | `docs/PACKAGES.md` | Single source of truth for all image packages. |
| `AI_COSIGN_PIN` | `v2.6.3` (Binary) | Version required for rpm-ostree compatibility. |

---

## 🏗️ LIVE ENVIRONMENT STATE

- **Workspace Path:** `/home/corey_dl_taylor/CloudWS-bootc`
- **User Home:** `/home/corey_dl_taylor`
- **`gcloud` State:** ⚠️ **WARNING:** Using temporary config in `/tmp/tmp.HwF1Lwhwnm`. Credentials will NOT persist across session resets.
- **Bootc Linter:** `v1.1.6+` — Fatal on `/var` content missing from `tmpfiles.d`.
- **NVIDIA Strategy:** Default to **Open Kernel Modules** (`nvidia-open`). Blackwell safety enabled.
- **Philosophy:** **Hardware & Environment Agnostic**. Supports all vendors (Intel/AMD/NVIDIA/ARM) and deployment types (Bare-metal, VM, OCI, WSL2/g).
- **Para-virt:** Standardized on GPU-PV, SR-IOV, and virtio-gpu for universal hardware acceleration across all environments.

---

## 🛰️ COORDINATION LOGS (v0.1.x Stream)

```version-log
[v0.1.8] - 2026-04-21: Unified Image v0.1.8; Role Engine; Optimized CI; Upstream Patches.
[v0.1.7] - 2026-04-18: NVIDIA 595+ & WSL 2.7.0 stability workarounds.
[v0.1.6] - 2026-04-16: NVIDIA Open Modules standardization; CDI generation.
[v0.1.5] - 2026-04-14: GNOME 50 transition; DNF5 build shift.
[v0.1.4] - 2026-03-25: Unified Image architecture; Role-at-boot.
```

---

## 🚨 AGENT HAND-OFF PROTOCOL

1. **JOURNAL:** Append to `.ai-context/ai-journal.md` at end of session.
2. **KNOWLEDGE:** Update `.ai-context/knowledge-base.md` if "Why" changed.
3. **ENVIRONMENT:** Update THIS FILE if a global "baseline" changed.
4. **VERSION:** Increment `VERSION` file if core architecture moved.
