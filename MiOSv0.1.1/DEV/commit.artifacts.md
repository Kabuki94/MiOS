# MiOS v0.1.1 — Development & Commit Artifacts
Generated: Mon Apr 27 03:56:54 AM UTC 2026

## 🛠️ Repository Status: Rootfs-Native & FOSS-AI-Native
The repository has been flattened to mirror a Linux root filesystem and scrubbed of all proprietary identifiers.

## 🛠️ Git Context
### Clone Instructions
```bash
git clone https://github.com/Kabuki94/MiOS.git
```

### Final Baseline Commit
```text
commit fd2f02b931c04919cf8921bc873d565f82602511
Author: Kabu.ki <kabu.com>
Date:   Mon Apr 27 03:48:13 2026 +0000

    ./MiOSv0.1.1/DEV/commit.artifacts.md
```

## 📄 Environment Configuration (emv dotfiles)
### .env (Baseline)
```ini
# MiOS AI-AGENT ENVIRONMENT (v2.1.0)
# NOTE: User-adjustable variables (Images, Accounts, Flatpaks) are consolidated in .env.mios
AI_ARCH_BASELINE=v2.1.0
AI_DNF_POLICY=--setopt=install_weak_deps=False
AI_WSL_GATING=ConditionVirtualization=!wsl
AI_OVERLAY_PATH=
AI_PKG_SOURCE=specs/engineering/2026-04-26-Artifact-ENG-001-Packages.md
AI_COSIGN_PIN=v2.6.3
AI_WORKSPACE_TYPE=bootable-container
AI_BASE_IMAGE="${MIOS_BASE_IMAGE:-ghcr.io/ublue-os/ucore-hci:stable-nvidia}"
AI_JOURNALING_LAW=MANDATORY
```

### .env.mios (System Defaults)
```ini
# MiOS Unified Environment Variables
# This file consolidates user-configurable variables for the MiOS build pipeline.
# Documentation and defaults are indexed here.

# ============================================
# 1. Base OCI Images
# ============================================
# Default base image for the MiOS build.
MIOS_BASE_IMAGE="ghcr.io/ublue-os/ucore-hci:stable-nvidia"

# Image for bootc-image-builder (BIB)
MIOS_BIB_IMAGE="quay.io/centos-bootc/bootc-image-builder:latest"

# ============================================
# 2. MiOS Personal Information & Accounts
# ============================================
# Default Linux username to be created.
MIOS_DEFAULT_USER="mios"

# Default password for the created user (PlainText - will be hashed during build).
# It is highly recommended to provide a pre-hashed SHA-512 string if possible.
MIOS_DEFAULT_USER_PASSWORD="changeme"

# Administrator/Root password.
MIOS_ADMIN_PASSWORD="changeme"

# ============================================
# 3. Layered Flatpaks
# ============================================
# Comma-separated list of Flatpak application IDs to install on first boot.
# Example: "org.gnome.Epiphany,com.github.tchx84.Flatseal"
MIOS_FLATPAKS="org.gnome.Epiphany,com.github.tchx84.Flatseal,io.github.kolunmi.Bazaar,com.mattjakeman.ExtensionManager"

# ============================================
# 4. Repository & Release Metadata
# ============================================
MIOS_REPO_URL="https://github.com/kabuki94/mios"
MIOS_IMAGE_NAME="ghcr.io/kabuki94/mios"

# ============================================
# 5. Build Configuration
# ============================================
# Google Cloud Project ID (if using cloud-build)
MIOS_GCP_PROJECT="cloudws-os"

# GCS bucket for build artifacts and results
MIOS_GCS_BUCKET="gs://mios-vertex-autogen-cloudws-os"
```

### identity.env.example (User Parameters Template)
```ini
# MiOS User Identity Configuration
# Copy this to user/identity.env and fill in your values.
# Plaintext passwords are NEVER stored; use SHA-512 hashes.

# The primary system user (Default: mios)
MIOS_USER="mios"

# SHA-512 crypt-style hash (e.g., generated via 'openssl passwd -6')
# Leave empty to prompt during first boot (recommended for local builds).
MIOS_PASSWORD_HASH=""

# Static hostname (e.g., "kabu-ws"). 
# If left as "mios", a unique tag (mios-XXXXX) is generated on first boot.
MIOS_HOSTNAME="mios"

# Primary Timezone (e.g., "UTC", "America/New_York")
MIOS_TIMEZONE="UTC"

# Keyboard Layout (e.g., "us")
MIOS_KEYBOARD="us"
```

## 🏗️ Build & Synchronization Logs
### Final Bootstrap Run (Manifest Sync)
```text
🚀 Initializing MiOS Agent Workspace...
📜 Loading unified environment from .env.mios...
📄 Generating directory manifests...
Generated specs/manifest.json
Generated .ai/foundation/memories/manifest.json
Generated artifacts/manifest.json.gz
Generated automation/manifest.json
Generated tools/manifest.json
Generated evals/manifest.json
Generated agents/research/manifest.json
Generated root-manifest.json
📖 Syncing Wiki...
📖 Syncing Wiki Documentation...
✅ Updated specs/engineering/2026-04-26-Artifact-ENG-002-Scripts-Index.md
✅ Propagated sync values to README.md
✅ Propagated sync values to INDEX.md
✅ Propagated sync values to INDEX.md
✅ Propagated sync values to INDEX.md
✅ Propagated sync values to INDEX.md
✅ Propagated sync values to specs/Home.md
🧠 Generating Unified Knowledge Base (RAG Snapshot)...
🧠 Generating Unified Knowledge Base: artifacts/repo-rag-snapshot.json.gz...
✅ UKB generated with 457 nodes (including 0 build logs).
🧪 Initializing agents/research (Agent Starter Pack)...
uv sync && npm --prefix frontend install
Resolved 256 packages in 1ms
Downloading jupyterlab (11.9MiB)
Downloading aiohttp (1.7MiB)
Downloading google-cloud-aiplatform (8.0MiB)
Downloading cryptography (4.5MiB)
Downloading grpcio (6.5MiB)
Downloading pyarrow (46.6MiB)
Downloading widgetsnbextension (2.1MiB)
Downloading sqlalchemy (3.2MiB)
Downloading notebook (13.9MiB)
Downloading google-cloud-discoveryengine (3.2MiB)
Downloading debugpy (4.1MiB)
Downloading babel (9.7MiB)
Downloading google-api-python-client (14.3MiB)
Downloading jedi (1.5MiB)
Downloading agent-starter-pack (4.7MiB)
Downloading google-adk (2.7MiB)
  × Failed to download `google-cloud-discoveryengine==0.13.12`
  ├─▶ Failed to extract archive: google_cloud_discoveryengine-0.13.12-py3-none-any.whl
  ├─▶ I/O operation failed during extraction
  ╰─▶ failed to flush file
      `/home/corey_dl_taylor/.cache/uv/.tmpJQIWcj/google/cloud/discoveryengine_v1/types/grounded_generation_service.py`:
      No space left on device (os error 28)
  help: `google-cloud-discoveryengine` (v0.13.12) was included because
        `deep-search` (v0.1.0) depends on `google-adk` (v1.31.1) which depends on
...
```

## 📁 Flattened Hierarchy Snapshot
```text
agents/
ai-context.json
artifacts/
automation/
config/
Containerfile
CONTRIBUTING.md
etc/
evals/
home/
identity.env.example
image-versions.yml
INDEX.md
install.ps1
install.sh*
JOURNAL.md@
Justfile
LICENSE
LICENSES.md
lifecycle.json
llms.txt
mios-build-local.ps1
MiOSv0.1.1/
preflight.ps1
push-to-github.ps1
README.md
renovate.json
root-manifest.json
SECURITY.md
SELF-BUILD.md
specs/
tools/
usr/
var/
VERSION

usr/: bin
lib
libexec
local
share...
etc/: skel...
home/: mios...
```
