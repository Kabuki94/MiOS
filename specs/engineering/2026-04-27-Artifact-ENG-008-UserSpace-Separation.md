# ENG-008: User-Space Separation and XDG Compliance

**Date:** 2026-04-27
**Version:** MiOS v0.1.3
**Status:** Implementation
**Author:** AI Agent (Claude)

---

## Executive Summary

Separate **user-space** from **repository root** to enable:
- Mutable, environment-independent user configurations
- XDG Base Directory compliance
- Transient credentials and secrets (never committed)
- User-specific settings, dotfiles, and preferences
- Per-user OCI image references and container configurations

---

## Problem Statement

### Current Issues

1. **User variables in repository root:**
   - `.env` file contains user-specific configuration
   - OCI image names, credentials, and preferences in version control
   - No separation between system defaults and user overrides

2. **Non-portable configurations:**
   - Hard-coded paths and credentials
   - Environment-dependent settings in committed files
   - Build-time variables mixed with user preferences

3. **FHS compliance incomplete:**
   - User-space files at repository root (not FHS)
   - No XDG Base Directory support
   - Missing HOME directory integration

4. **Security concerns:**
   - Credentials in `.env` could be accidentally committed
   - Passwords and keys in repository
   - No separation of secrets from configuration

---

## Solution: XDG Base Directory Specification

### XDG Standard Paths

```bash
# User-specific data files
XDG_DATA_HOME="${HOME}/.local/share"
  → ${XDG_DATA_HOME}/mios/

# User-specific configuration files
XDG_CONFIG_HOME="${HOME}/.config"
  → ${XDG_CONFIG_HOME}/mios/

# User-specific cache files
XDG_CACHE_HOME="${HOME}/.cache"
  → ${XDG_CACHE_HOME}/mios/

# User-specific state data (logs, history)
XDG_STATE_HOME="${HOME}/.local/state"
  → ${XDG_STATE_HOME}/mios/

# User-specific runtime files (sockets, PIDs)
XDG_RUNTIME_DIR="/run/user/${UID}"
  → ${XDG_RUNTIME_DIR}/mios/
```

### Proposed User-Space Structure

```
$HOME/.config/mios/                    # XDG_CONFIG_HOME
├── env.toml                           # User environment configuration (replaces .env)
├── build.toml                         # Build-time configuration
├── images.toml                        # OCI image references
├── credentials/                       # Credentials (gitignored, never synced)
│   ├── github-token                   # GitHub PAT
│   ├── registry-auth.json             # Container registry auth
│   └── ssh-keys/                      # SSH keys for repos
├── flatpaks.list                      # User-selected Flatpak applications
├── preferences.toml                   # User preferences (theme, etc.)
└── dotfiles/                          # User dotfiles to install
    ├── .bashrc.d/mios.sh              # Shell integration
    ├── .vimrc                         # Editor configs
    └── .gitconfig                     # Git configuration

$HOME/.local/share/mios/               # XDG_DATA_HOME
├── artifacts/                         # User-downloaded artifacts
├── images/                            # Downloaded OCI images
├── templates/                         # User templates
└── plugins/                           # User plugins

$HOME/.cache/mios/                     # XDG_CACHE_HOME
├── podman/                            # Podman build cache
├── downloads/                         # Temporary downloads
└── build-cache/                       # Build artifacts cache

$HOME/.local/state/mios/               # XDG_STATE_HOME
├── logs/                              # User build logs
│   └── build-20260427T*.log
├── history.log                        # Command history
└── last-build.json                    # Last build metadata

/run/user/${UID}/mios/                 # XDG_RUNTIME_DIR
├── podman.sock                        # Rootless Podman socket
└── build.lock                         # Build lock file
```

---

## Repository Structure Changes

### Before (Current - Mixed)

```
mios/                                  # Repository root
├── .env                               # ❌ User config in repo
├── .editorconfig                      # ✅ Editor defaults (OK)
├── .gitignore                         # ✅ Version control (OK)
├── Containerfile                      # ✅ System (OK)
├── Justfile                           # ✅ Build system (OK)
├── VERSION                            # ✅ System (OK)
├── logs/                              # ❌ Should be in XDG_STATE_HOME
├── config/artifacts/*.toml            # ⚠️  System defaults (OK, but needs user override)
└── ...
```

### After (Separated)

```
mios/                                  # Repository root (SYSTEM ONLY)
├── .editorconfig                      # Editor defaults
├── .gitignore                         # Version control
├── Containerfile                      # OCI build instructions
├── Justfile                           # Build orchestration
├── VERSION                            # System version
├── etc/                               # System configuration defaults
│   └── mios/
│       ├── default.env.toml           # Default environment (template)
│       ├── default.build.toml         # Default build config (template)
│       └── default.images.toml        # Default image references (template)
├── config/artifacts/*.toml            # BIB system defaults (read-only)
├── usr/                               # System files (installed to image)
├── var/                               # System variable data (tmpfiles.d)
├── home/                              # Home directory skeleton (for new users)
│   └── mios/
│       └── .config/mios/
│           └── README.md              # Instructions for user setup
└── automation/                        # Build automation (system)

$HOME/.config/mios/                    # USER SPACE (mutable, transient)
├── env.toml                           # User environment overrides
├── build.toml                         # User build configuration
├── images.toml                        # User OCI image preferences
├── credentials/                       # User credentials (NEVER COMMITTED)
│   ├── .gitignore                     # Ignore all credentials
│   └── README.md                      # Credential setup instructions
└── ...

$HOME/.local/share/mios/               # USER DATA
$HOME/.cache/mios/                     # USER CACHE
$HOME/.local/state/mios/               # USER STATE (logs)
/run/user/${UID}/mios/                 # USER RUNTIME
```

---

## Configuration File Formats

### 1. `$HOME/.config/mios/env.toml` (User Environment)

Replaces `.env` - TOML format for better structure:

```toml
# MiOS User Environment Configuration
# This file overrides system defaults in /usr/share/mios/config/default.env.toml

[mios]
version = "v0.1.3"
user = "your-username"

[build]
# Build-time configuration
no_cache = false
parallel_jobs = 4
verbose = false

[logging]
# Where to store user build logs
log_dir = "${XDG_STATE_HOME}/mios/logs"
retain_days = 30
```

### 2. `$HOME/.config/mios/images.toml` (OCI Images)

User-specific image references:

```toml
# MiOS OCI Image Configuration
# Override default images with your preferred registries

[images]
# Base image for MiOS builds
base = "ghcr.io/ublue-os/ucore-hci:stable-nvidia"

# Bootc Image Builder
bib = "quay.io/centos-bootc/bootc-image-builder:latest"

# Output image name and tags
output_name = "localhost/mios"
output_tags = ["latest", "v0.1.3", "custom"]

[registry]
# Container registry settings
default = "ghcr.io"
username = ""  # Set via credentials/registry-auth.json instead
push_on_build = false
```

### 3. `$HOME/.config/mios/build.toml` (Build Configuration)

User build preferences:

```toml
# MiOS Build Configuration

[artifacts]
# Which artifacts to generate
enabled = ["qcow2", "iso"]

[qcow2]
disk_size = "50G"
format = "qcow2"

[iso]
installer_type = "anaconda"
include_netinstall = true

[flatpaks]
# Enable Flatpak installation in image
enabled = true
source_file = "${XDG_CONFIG_HOME}/mios/flatpaks.list"

[nvidia]
# NVIDIA-specific settings (if using NVIDIA GPU)
enabled = true
driver_version = "latest"
cuda = true

[amd]
# AMD-specific settings
enabled = false
rocm = false
```

### 4. `$HOME/.config/mios/flatpaks.list` (Flatpak Applications)

User-selected Flatpaks to install:

```
# One Flatpak app per line
org.mozilla.firefox
com.visualstudio.code
org.blender.Blender
org.gimp.GIMP
```

### 5. `$HOME/.config/mios/credentials/` (Secrets - NEVER COMMITTED)

```bash
# credentials/.gitignore
*
!.gitignore
!README.md

# credentials/README.md
# MiOS Credentials Directory
#
# This directory is automatically ignored by git.
# Store sensitive data here:
#
# - github-token          # GitHub Personal Access Token
# - registry-auth.json    # Podman/Docker registry authentication
# - ssh-keys/             # SSH keys for private repositories
# - mok-key.priv          # Machine Owner Key (MOK) for Secure Boot
#
# Never commit credentials to version control!
```

---

## Environment Variable Loading Priority

Variables are loaded in priority order (later overrides earlier):

1. **System Defaults** (`/usr/share/mios/config/default.*.toml`)
   - Shipped with MiOS
   - Read-only, version-controlled
   - Fallback values

2. **User Configuration** (`${XDG_CONFIG_HOME}/mios/*.toml`)
   - User-specific overrides
   - Mutable, transient
   - Not version-controlled

3. **Environment Variables** (e.g., `MIOS_BASE_IMAGE`)
   - Shell environment
   - Highest priority
   - Temporary, session-specific

4. **Command-Line Arguments** (e.g., `just build --base-image=...`)
   - Direct overrides
   - Ultimate priority

### Loading Logic

```bash
# tools/load-user-env.sh

# 1. Load system defaults
source /usr/share/mios/config/default.env.sh

# 2. Load user configuration (TOML → shell variables)
if [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/mios/env.toml" ]; then
    eval "$(toml-to-env ${XDG_CONFIG_HOME:-$HOME/.config}/mios/env.toml)"
fi

# 3. Environment variables already set take precedence (no action needed)

# 4. Export variables for use in Justfile and Containerfile
export MIOS_BASE_IMAGE="${MIOS_BASE_IMAGE:-$base_image}"
export MIOS_BIB_IMAGE="${MIOS_BIB_IMAGE:-$bib_image}"
export MIOS_OUTPUT_NAME="${MIOS_OUTPUT_NAME:-$output_name}"
# ... etc
```

---

## Migration Path

### Step 1: Initialize User-Space (First-Time Setup)

```bash
# tools/init-user-space.sh - Run once per user

#!/usr/bin/env bash
set -euo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

echo "🏗️  Initializing MiOS user-space..."

# Create XDG directories
mkdir -p "${XDG_CONFIG_HOME}/mios/credentials"
mkdir -p "${XDG_DATA_HOME}/mios/artifacts"
mkdir -p "${XDG_CACHE_HOME}/mios/podman"
mkdir -p "${XDG_STATE_HOME}/mios/logs"

# Copy default templates
cp etc/mios/default.env.toml "${XDG_CONFIG_HOME}/mios/env.toml"
cp etc/mios/default.build.toml "${XDG_CONFIG_HOME}/mios/build.toml"
cp etc/mios/default.images.toml "${XDG_CONFIG_HOME}/mios/images.toml"

# Create credentials .gitignore
cat > "${XDG_CONFIG_HOME}/mios/credentials/.gitignore" <<EOF
*
!.gitignore
!README.md
EOF

# Create credentials README
cat > "${XDG_CONFIG_HOME}/mios/credentials/README.md" <<EOF
# MiOS Credentials

This directory stores sensitive data and is automatically ignored by git.

## Files:
- github-token          # GitHub PAT
- registry-auth.json    # Container registry auth
- ssh-keys/             # SSH keys
- mok-key.priv          # Secure Boot MOK key

Never commit credentials!
EOF

echo "✅ User-space initialized at:"
echo "   Config:  ${XDG_CONFIG_HOME}/mios/"
echo "   Data:    ${XDG_DATA_HOME}/mios/"
echo "   Cache:   ${XDG_CACHE_HOME}/mios/"
echo "   State:   ${XDG_STATE_HOME}/mios/"
echo ""
echo "📝 Next steps:"
echo "   1. Edit ${XDG_CONFIG_HOME}/mios/env.toml"
echo "   2. Edit ${XDG_CONFIG_HOME}/mios/images.toml"
echo "   3. Add credentials to ${XDG_CONFIG_HOME}/mios/credentials/"
echo "   4. Run: just build"
```

### Step 2: Migrate Existing .env

```bash
# tools/migrate-env-to-toml.sh

#!/usr/bin/env bash
set -euo pipefail

OLD_ENV=".env"
NEW_TOML="${XDG_CONFIG_HOME:-$HOME/.config}/mios/env.toml"

if [ ! -f "$OLD_ENV" ]; then
    echo "No .env file found to migrate."
    exit 0
fi

echo "🔄 Migrating .env → $NEW_TOML"

# Parse .env and convert to TOML
# (Implementation would parse shell variables and convert to TOML format)

echo "✅ Migration complete"
echo "⚠️  Please review $NEW_TOML and remove $OLD_ENV if satisfied"
```

### Step 3: Update Build System

Update `Justfile` to load user-space configuration:

```justfile
# Load user environment before any target
_load-env:
    @./tools/load-user-env.sh

# All build targets depend on _load-env
build: _load-env artifact
    podman build --no-cache \
        --build-arg BASE_IMAGE={{env_var("MIOS_BASE_IMAGE")}} \
        --build-arg MIOS_FLATPAKS={{env_var("MIOS_FLATPAKS")}} \
        -t {{env_var("MIOS_OUTPUT_NAME")}} .
```

---

## Security Benefits

### 1. Credentials Never Committed

```bash
# .gitignore (repository root)
/.env                    # Old .env (if still exists)

# User-space is OUTSIDE repository
# Credentials in $HOME/.config/mios/credentials/ are never tracked
```

### 2. Separation of System vs User

| Type | Location | Committed | Mutable |
|------|----------|-----------|---------|
| System defaults | `/usr/share/mios/config/` | ✅ Yes | ❌ No |
| User config | `$HOME/.config/mios/` | ❌ No | ✅ Yes |
| User data | `$HOME/.local/share/mios/` | ❌ No | ✅ Yes |
| User logs | `$HOME/.local/state/mios/` | ❌ No | ✅ Yes |
| Credentials | `$HOME/.config/mios/credentials/` | ❌ No | ✅ Yes |

### 3. Transient Across Environments

User moves between machines → configurations remain in `$HOME`, repository stays clean.

---

## Compatibility with FOSS AI APIs

FOSS AI APIs can discover user-space via XDG:

```python
# Example: Ollama discovers user MiOS config
import os
from pathlib import Path

xdg_config = Path(os.getenv("XDG_CONFIG_HOME", Path.home() / ".config"))
mios_config = xdg_config / "mios" / "env.toml"

if mios_config.exists():
    user_config = load_toml(mios_config)
    # Use user's preferred base image, settings, etc.
```

---

## Implementation Checklist

- [ ] Create `etc/mios/default.*.toml` templates
- [ ] Create `tools/init-user-space.sh` script
- [ ] Create `tools/load-user-env.sh` loader
- [ ] Create `tools/migrate-env-to-toml.sh` migration
- [ ] Update `Justfile` to load user environment
- [ ] Update `.gitignore` to exclude user-space
- [ ] Update documentation (README, SELF-BUILD)
- [ ] Test multi-environment portability
- [ ] Create spec: ENG-008-UserSpace-Separation.md ✅

---

## Future Enhancements

1. **Multi-Profile Support**
   - `$HOME/.config/mios/profiles/development.toml`
   - `$HOME/.config/mios/profiles/production.toml`
   - `just build --profile=development`

2. **Dotfile Management**
   - Sync dotfiles from `$HOME/.config/mios/dotfiles/` into built images
   - Symlink management for `$HOME` integration

3. **Secret Management Integration**
   - HashiCorp Vault support
   - 1Password CLI integration
   - `pass` (password-store) integration

4. **Cloud Sync**
   - Optional `$HOME/.config/mios/` sync via git (user-owned private repo)
   - Encrypted credential storage

---

## References

- [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)
- [FHS 3.0 - Filesystem Hierarchy Standard](https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html)
- [12-Factor App - Config](https://12factor.net/config)
- [TOML v1.0.0](https://toml.io/en/v1.0.0)

---

**Status:** Design Complete - Ready for Implementation
**Next:** Create user-space initialization tooling
