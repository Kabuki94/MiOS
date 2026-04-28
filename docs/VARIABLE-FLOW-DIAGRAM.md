# MiOS Variable Flow Diagram

**Visual reference for how variables propagate through the MiOS build and deployment pipeline**

---

## Complete Variable Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      USER CONFIGURATION LAYER                           │
│                     (~/.config/mios/*.toml)                             │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    │               │               │
              ┌─────▼─────┐   ┌────▼────┐   ┌──────▼──────┐
              │ env.toml  │   │images   │   │flatpaks.list│
              │           │   │.toml    │   │             │
              └───────────┘   └─────────┘   └─────────────┘
                    │               │               │
              ┌─────┴───────────────┴───────────────┴─────┐
              │                                            │
      MIOS_USER                                    MIOS_BASE_IMAGE
      MIOS_HOSTNAME                                MIOS_IMAGE_NAME
      MIOS_PASSWORD_HASH                           MIOS_BIB_IMAGE
      MIOS_AI_MODEL                                MIOS_FLATPAKS
      MIOS_AI_ENDPOINT
      MIOS_AI_KEY (in ai.env)
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    ENVIRONMENT VARIABLE LOADER                          │
│                   (tools/load-user-env.sh)                              │
│                                                                         │
│  • Parses TOML files with Python/jq                                    │
│  • Exports MIOS_* environment variables                                │
│  • Provides fallback to defaults                                       │
└─────────────────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         JUSTFILE LAYER                                  │
│                     (Build Orchestration)                               │
│                                                                         │
│  IMAGE_NAME := env_var_or_default("MIOS_IMAGE_NAME", "...")            │
│  BIB        := env_var_or_default("MIOS_BIB_IMAGE", "...")             │
│  BASE_IMAGE := env_var_or_default("MIOS_BASE_IMAGE", "...")            │
└─────────────────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    PODMAN BUILD INVOCATION                              │
│                                                                         │
│  podman build --no-cache \                                             │
│      --build-arg BASE_IMAGE="$MIOS_BASE_IMAGE" \                       │
│      --build-arg MIOS_USER="$MIOS_USER" \                              │
│      --build-arg MIOS_PASSWORD_HASH="$MIOS_PASSWORD_HASH" \            │
│      --build-arg MIOS_HOSTNAME="$MIOS_HOSTNAME" \                      │
│      --build-arg MIOS_FLATPAKS="$MIOS_FLATPAKS" \                      │
│      -t localhost/mios:latest .                                        │
└─────────────────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                       CONTAINERFILE (OCI Build)                         │
│                                                                         │
│  ARG BASE_IMAGE=ghcr.io/ublue-os/ucore-hci:stable-nvidia               │
│  ARG MIOS_USER=mios                                                    │
│  ARG MIOS_PASSWORD_HASH=                                               │
│  ARG MIOS_HOSTNAME=mios                                                │
│  ARG MIOS_FLATPAKS=                                                    │
│                                                                         │
│  FROM ${BASE_IMAGE}                                                    │
│  COPY --from=ctx /ctx /ctx                                             │
│  RUN /ctx/automation/build.sh                                          │
└─────────────────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                   AUTOMATION SCRIPTS LAYER                              │
│                  (automation/*.sh - 49 scripts)                         │
│                                                                         │
│  01-repos.sh          → Install repos (no user vars)                   │
│  31-user.sh           → Reads MIOS_USER, MIOS_PASSWORD_HASH            │
│  32-hostname.sh       → Reads MIOS_HOSTNAME                            │
│  42-flatpak.sh        → Reads MIOS_FLATPAKS (from injected list)       │
│  ...                                                                    │
└─────────────────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      OCI IMAGE LAYERS                                   │
│                  (localhost/mios:latest)                                │
│                                                                         │
│  • User created with MIOS_USER and MIOS_PASSWORD_HASH                  │
│  • Hostname set to MIOS_HOSTNAME                                       │
│  • Flatpaks from MIOS_FLATPAKS pre-installed                           │
│  • Base from MIOS_BASE_IMAGE                                           │
└─────────────────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    BOOTC DEPLOYMENT                                     │
│           (bootc install to-existing-root)                              │
│                                                                         │
│  • Image deployed to /sysroot                                          │
│  • /etc overlay preserved                                              │
│  • /var state preserved                                                │
└─────────────────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                     RUNTIME LAYER                                       │
│         (System booted from MiOS image)                                 │
└─────────────────────────────────────────────────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
        ▼                       ▼
┌───────────────┐       ┌───────────────┐
│/etc/mios/     │       │systemd units  │
│runtime.env    │       │               │
│               │       │EnvironmentFile│
│MIOS_AI_*      │───────►=/etc/mios/    │
│MIOS_ROLE      │       │runtime.env    │
│               │       │               │
└───────────────┘       └───────────────┘
        │                       │
        ▼                       ▼
┌───────────────┐       ┌───────────────┐
│shell profiles │       │containers     │
│               │       │               │
│source /usr/   │       │.container     │
│lib/profile.d/ │       │files with     │
│mios-env.sh    │       │Environment=   │
└───────────────┘       └───────────────┘
```

---

## Variable Lifecycle by Type

### Build-Time Variables (ARG)

```
User TOML → load-user-env.sh → MIOS_* env vars →
podman build --build-arg → Containerfile ARG →
automation/*.sh → Image layers → [DISCARDED after build]
```

**Characteristics:**
- ❌ NOT in final image
- ✅ Available during `RUN` instructions
- ✅ User-configurable
- 🔒 Secure for secrets (not persisted)

**Examples:**
- MIOS_BASE_IMAGE
- MIOS_USER
- MIOS_PASSWORD_HASH
- MIOS_FLATPAKS

---

### Runtime Variables (ENV)

```
/etc/mios/runtime.env → systemd EnvironmentFile →
systemd units → Process environment →
shell profiles → User sessions
```

**Characteristics:**
- ✅ In final image (if using ENV) OR external file
- ✅ Mutable after deployment
- ✅ User-configurable
- ⚠️ Should NOT use ENV for secrets in Containerfile

**Examples:**
- MIOS_AI_KEY (from /etc/mios/runtime.env or ~/.config/mios/ai.env)
- MIOS_AI_MODEL
- MIOS_AI_ENDPOINT
- MIOS_HOSTNAME (can be overridden with hostnamectl)

---

### Auto-Detected Variables

```
System boot → automation/*-detect.sh →
/var/lib/mios/state/* → Read by services
```

**Characteristics:**
- ❌ NOT user-configurable
- ✅ System-managed
- 🔄 Updated on each boot (or on-demand)

**Examples:**
- MIOS_ROLE (desktop | k3s | ha)
- GPU_VENDOR (nvidia | amd | intel | none)
- MIOS_PLATFORM (systemd-detect-virt output)

---

## Variable Tracking with @track: Markers

```
Source Files                         .ai/variables.json
─────────────                        ──────────────────

Containerfile:19                     {
ARG BASE_IMAGE=ghcr.io/...             "MIOS_BASE_IMAGE": {
# @track:IMG_BASE                       "marker": "@track:IMG_BASE",
                                        "tracked_in": [
Justfile:45                               "Containerfile:19",
--build-arg BASE_IMAGE={{...}}            "Justfile:45"
                                        ]
                                      }
                                    }

                AI Agent Knows Both Locations
                         │
                         ▼
              When user changes MIOS_BASE_IMAGE,
              AI updates BOTH locations automatically
```

---

## Security Layers

```
┌─────────────────────────────────────────────────┐
│         CRITICAL SECRETS (Never Commit)         │
│                                                 │
│  MIOS_PASSWORD_HASH → Build ARG only (ephemeral)│
│  MIOS_AI_KEY        → ~/.config/mios/ai.env     │
│                       (mode 600, .gitignore'd)  │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│      LOW-SECURITY CONFIG (Committable)          │
│                                                 │
│  MIOS_BASE_IMAGE    → images.toml               │
│  MIOS_USER          → env.toml                  │
│  MIOS_FLATPAKS      → flatpaks.list             │
│  MIOS_AI_MODEL      → env.toml                  │
│  MIOS_AI_ENDPOINT   → env.toml                  │
└─────────────────────────────────────────────────┘
```

**Security Rules:**
1. **NEVER** put `MIOS_PASSWORD_HASH` in TOML files committed to git
2. **NEVER** put `MIOS_AI_KEY` in TOML files committed to git
3. **ALWAYS** use `ai.env` for secrets (mode 600)
4. **ALWAYS** pass secrets via `--build-arg` (not ENV in Containerfile)

---

## File Permissions Map

```
Location                          Permissions  Owner      Security
──────────────────────────────────────────────────────────────────
~/.config/mios/env.toml           644          user:user  Low
~/.config/mios/images.toml        644          user:user  Low
~/.config/mios/build.toml         644          user:user  Low
~/.config/mios/flatpaks.list      644          user:user  Low
~/.config/mios/ai.env             600          user:user  CRITICAL
/etc/mios/runtime.env             644          root:root  Low
/var/lib/mios/state/*             644          root:root  Low
/usr/share/mios/*                 644          root:root  Immutable
```

---

## Variable Priority (Override Order)

```
Lowest Priority
    │
    ├─ 1. System Defaults (/usr/share/mios/defaults.env)
    │
    ├─ 2. User TOML Config (~/.config/mios/*.toml)
    │
    ├─ 3. Environment Variables (export MIOS_BASE_IMAGE=...)
    │
    └─ 4. Command-Line Arguments (--build-arg BASE_IMAGE=...)
         │
         ▼
Highest Priority
```

**Example:**
```bash
# Priority order demonstration
DEFAULT="ghcr.io/ublue-os/ucore-hci:stable-nvidia"  # 1. Default
# User edits ~/.config/mios/images.toml → "ghcr.io/ublue-os/ucore:stable"  # 2. TOML
export MIOS_BASE_IMAGE="registry.fedoraproject.org/fedora-bootc:rawhide"  # 3. Env var
podman build --build-arg BASE_IMAGE="custom/image:latest" ...  # 4. Arg (WINS)

# Final value used: "custom/image:latest"
```

---

## TOML File Structure

### env.toml
```toml
[mios]
user = "USERNAME"           → MIOS_USER
hostname = "HOSTNAME"       → MIOS_HOSTNAME

[ai]
model = "MODEL"             → MIOS_AI_MODEL
endpoint = "ENDPOINT"       → MIOS_AI_ENDPOINT
temperature = 0.7           → MIOS_AI_TEMPERATURE
```

### images.toml
```toml
[base]
image = "REGISTRY/IMAGE:TAG" → MIOS_BASE_IMAGE

[builder]
image = "BIB_IMAGE"          → MIOS_BIB_IMAGE

[output]
name = "OUTPUT_NAME"         → MIOS_IMAGE_NAME
tag = "TAG"                  → (appended to name)
```

### flatpaks.list
```
APP_ID_1                     ┐
APP_ID_2                     ├→ MIOS_FLATPAKS
APP_ID_3                     │  (comma-joined)
...                          ┘
```

---

## Build-Time vs Runtime Variables

### Build-Time (ARG)

```dockerfile
ARG MIOS_USER=mios
ARG MIOS_PASSWORD_HASH=

RUN useradd -m -p "${MIOS_PASSWORD_HASH}" "${MIOS_USER}"
# Variables available during build
# NOT in final image layers
```

**Use Cases:**
- User creation
- Password hash injection
- Flatpak app selection
- Base image selection

**Advantage:** Secrets don't persist in image

---

### Runtime (ENV or Files)

```dockerfile
# Option 1: ENV (baked into image)
ENV MIOS_AI_MODEL=llama3.1:8b

# Option 2: External file (preferred for mutability)
# /etc/mios/runtime.env:
# MIOS_AI_MODEL=llama3.1:8b
```

**Use Cases:**
- AI model selection
- API endpoints
- Feature flags
- Runtime configuration

**Advantage:** Can be changed without rebuild

---

## State Detection Flow

```
System Boot
    │
    ▼
┌────────────────────┐
│automation/         │
│*-detect.sh scripts │
└────────────────────┘
    │
    ├─ GPU Detection ──────────────► /var/lib/mios/state/gpu
    │  (lspci | grep VGA)             (nvidia|amd|intel|none)
    │
    ├─ Platform Detection ─────────► /var/lib/mios/state/platform
    │  (systemd-detect-virt)          (kvm|wsl|none|...)
    │
    └─ Role Detection ─────────────► /var/lib/mios/state/role
       (desktop env check)            (desktop|k3s|ha)
```

**Files:**
```bash
cat /var/lib/mios/state/gpu
# Output: nvidia

cat /var/lib/mios/state/role
# Output: desktop

cat /var/lib/mios/state/platform
# Output: none
```

---

## Variable Mutation Timeline

```
Pre-Build          Build-Time         Post-Build         Runtime
─────────          ──────────         ──────────         ───────

User edits         ARG consumed       Image tagged       bootc deploy
TOML files    ──►  by automation  ──► localhost/    ──►  to system
                   scripts            mios:latest

MIOS_USER=X        useradd X          [user X exists]    System boots
MIOS_BASE_IMAGE=Y  FROM Y             [layers from Y]    with user X
MIOS_FLATPAKS=Z    flatpak install Z  [apps Z installed] on base Y

                   ▲                                      │
                   │                                      │
                   └──── IMMUTABLE ──────────────────────┘
                         (baked into image)

                                                      Runtime vars
                                                      can change:
                                                      MIOS_AI_MODEL
                                                      MIOS_HOSTNAME
```

---

## Integration Points

### 1. Justfile → Podman
```just
build:
    podman build --build-arg BASE_IMAGE={{env_var_or_default("MIOS_BASE_IMAGE", "...")}} ...
```

### 2. Podman → Containerfile
```dockerfile
ARG BASE_IMAGE=ghcr.io/ublue-os/ucore-hci:stable-nvidia
FROM ${BASE_IMAGE}
```

### 3. Containerfile → Automation Scripts
```dockerfile
ARG MIOS_USER=mios
RUN /ctx/automation/31-user.sh
```

```bash
# automation/31-user.sh
useradd -m "${MIOS_USER}"
```

### 4. Automation Scripts → Image Layers
```bash
# Script output is committed to image
RUN /ctx/automation/build.sh
```

### 5. systemd → Runtime Environment
```ini
[Service]
EnvironmentFile=/etc/mios/runtime.env
ExecStart=/usr/bin/mios-service
```

---

## Quick Reference

### Where to Find Variables

| Variable | Build-Time Location | Runtime Location |
|----------|---------------------|------------------|
| MIOS_BASE_IMAGE | Containerfile ARG | N/A |
| MIOS_USER | Containerfile ARG | /etc/passwd |
| MIOS_PASSWORD_HASH | Containerfile ARG | /etc/shadow |
| MIOS_HOSTNAME | Containerfile ARG | /etc/hostname |
| MIOS_FLATPAKS | Containerfile ARG | /var/lib/flatpak/ |
| MIOS_AI_KEY | N/A | ~/.config/mios/ai.env |
| MIOS_AI_MODEL | N/A | /etc/mios/runtime.env |
| MIOS_ROLE | N/A | /var/lib/mios/state/role |
| GPU_VENDOR | N/A | /var/lib/mios/state/gpu |

---

**Generated:** 2026-04-28
**Version:** 1.0.0
**For:** MiOS v0.1.3
