# 🌐 AI-AGENT GLOBAL ENVIRONMENT & COORDINATION (AI-ENV)

> **MANDATORY READING FOR ALL AGENTS (CLAUDE, GEMINI, COPILOT)**
> This file tracks the live architectural baseline and environment-specific state.
> Update this file immediately upon implementing any cross-cutting change.

---

## 🛠️ CORE BASELINE ARGUMENTS

| VARIABLE | CURRENT VALUE | DESCRIPTION |
| :--- | :--- | :--- |
| `AI_ARCH_BASELINE` | **v2.3.5** | Current synchronized engineering baseline. |
| `AI_DNF_POLICY` | `"${DNF_SETOPT[@]}"` | Mandatory array usage for all package installs. |
| `AI_WSL_GATING` | `ConditionVirtualization=!wsl` | Standard for all service gating in WSL2. |
| `AI_OVERLAY_PATH` | `system_files/` | The ONLY directory for persistent system config. |
| `AI_PKG_SOURCE` | `docs/PACKAGES.md` | Single source of truth for all image packages. |
| `AI_COSIGN_PIN` | `v2.6.3` (Binary) | Version required for rpm-ostree compatibility. |

---

## 🏗️ LIVE ENVIRONMENT STATE

- **Workspace Path:** `/home/corey_dl_taylor/CloudWS-bootc`
- **User Home:** `/home/corey_dl_taylor`
- **`gcloud` State:** ⚠️ **WARNING:** Using temporary config in `/tmp/tmp.HwF1Lwhwnm`. Credentials will NOT persist across deep tree operations or session resets.
- **Bootc Linter:** `v1.1.6+` — Fatal on `/var` content missing from `tmpfiles.d`.
- **NVIDIA Strategy:** Default to **Open Kernel Modules** (`nvidia-open`). Blackwell safety enabled.

---

## 🛰️ COORDINATION LOGS (v2.x Stream)

```version-log
[v2.3.5] - 2026-04-21: Consolidated Role Engine; Unified overlay; Fixed CI rechunking; Patched NVIDIA 595+ and WSL 2.7.
[v2.3.4] - 2026-04-18: Renamed gpu-detect to gpu-status; Blackwell VFIO d3-idle fix.
[v2.2.7] - 2026-04-10: install.ps1 ASCII-only IRM fix.
[v2.2.0] - 2026-03-25: Unified Image; uupd adoption; Role-at-boot introduced.
```

---

## 🚨 AGENT HAND-OFF PROTOCOL

1. **JOURNAL:** Append to `.ai-context/ai-journal.md` at end of session.
2. **KNOWLEDGE:** Update `.ai-context/knowledge-base.md` if "Why" changed.
3. **ENVIRONMENT:** Update THIS FILE if a global "baseline" changed.
4. **VERSION:** Increment `VERSION` file if core architecture moved.
