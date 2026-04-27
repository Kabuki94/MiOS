#!/usr/bin/env bash
# MiOS User-Space Initialization
# Creates XDG-compliant user configuration directory structure
# and copies system default templates for user customization.
#
# Usage: ./tools/init-user-space.sh [--force]

set -euo pipefail

# XDG Base Directory variables with fallback defaults
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# MiOS-specific XDG paths
MIOS_CONFIG_DIR="${XDG_CONFIG_HOME}/mios"
MIOS_DATA_DIR="${XDG_DATA_HOME}/mios"
MIOS_CACHE_DIR="${XDG_CACHE_HOME}/mios"
MIOS_STATE_DIR="${XDG_STATE_HOME}/mios"
MIOS_RUNTIME_DIR="${XDG_RUNTIME_DIR}/mios"

# Template source directory (in repository)
TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/etc/mios/templates"

# Force flag (overwrite existing configs)
FORCE=false
if [[ "${1:-}" == "--force" ]]; then
    FORCE=true
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
info() {
    echo -e "${BLUE}ℹ️  ${NC}$*"
}

success() {
    echo -e "${GREEN}✅${NC} $*"
}

warn() {
    echo -e "${YELLOW}⚠️  ${NC}$*"
}

error() {
    echo -e "${RED}❌${NC} $*" >&2
}

# Check if templates exist
if [[ ! -d "$TEMPLATE_DIR" ]]; then
    error "Template directory not found: $TEMPLATE_DIR"
    error "Make sure you're running this script from the MiOS repository root."
    exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       MiOS User-Space Initialization (XDG Compliant)        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

info "Initializing MiOS user-space directories..."
echo ""

# Create XDG directory structure
info "Creating XDG Base Directory structure..."

mkdir -p "${MIOS_CONFIG_DIR}/credentials/ssh-keys"
success "Created: ${MIOS_CONFIG_DIR}/"

mkdir -p "${MIOS_DATA_DIR}/artifacts"
mkdir -p "${MIOS_DATA_DIR}/images"
mkdir -p "${MIOS_DATA_DIR}/templates"
mkdir -p "${MIOS_DATA_DIR}/plugins"
success "Created: ${MIOS_DATA_DIR}/"

mkdir -p "${MIOS_CACHE_DIR}/podman"
mkdir -p "${MIOS_CACHE_DIR}/downloads"
mkdir -p "${MIOS_CACHE_DIR}/build-cache"
success "Created: ${MIOS_CACHE_DIR}/"

mkdir -p "${MIOS_STATE_DIR}/logs"
success "Created: ${MIOS_STATE_DIR}/"

if [[ -d "$XDG_RUNTIME_DIR" ]]; then
    mkdir -p "${MIOS_RUNTIME_DIR}"
    success "Created: ${MIOS_RUNTIME_DIR}/"
else
    warn "XDG_RUNTIME_DIR not available (expected for non-login shells)"
fi

echo ""
info "Copying configuration templates..."

# Function to copy template if not exists or if forced
copy_template() {
    local template_file="$1"
    local dest_file="$2"
    local template_path="${TEMPLATE_DIR}/${template_file}"
    local dest_path="${MIOS_CONFIG_DIR}/${dest_file}"

    if [[ ! -f "$template_path" ]]; then
        warn "Template not found: $template_path (skipping)"
        return
    fi

    if [[ -f "$dest_path" ]] && [[ "$FORCE" != true ]]; then
        warn "File exists (skipping): ${dest_file}"
        echo "   Use --force to overwrite existing files"
    else
        cp "$template_path" "$dest_path"
        if [[ "$FORCE" == true ]] && [[ -f "$dest_path" ]]; then
            success "Overwrote: ${dest_file}"
        else
            success "Copied: ${dest_file}"
        fi
    fi
}

# Copy templates to user config directory
copy_template "default.env.toml" "env.toml"
copy_template "default.images.toml" "images.toml"
copy_template "default.build.toml" "build.toml"
copy_template "flatpaks.list" "flatpaks.list"

echo ""
info "Setting up credentials directory..."

# Create credentials .gitignore
cat > "${MIOS_CONFIG_DIR}/credentials/.gitignore" <<'EOF'
# MiOS Credentials - Ignore Everything
# This directory should NEVER be committed to version control

*
!.gitignore
!README.md
EOF
success "Created: credentials/.gitignore"

# Create credentials README
cat > "${MIOS_CONFIG_DIR}/credentials/README.md" <<'EOF'
# MiOS Credentials Directory

**⚠️  IMPORTANT: This directory is automatically ignored by git.**

This directory stores sensitive data and credentials. Files here will **never** be committed to version control.

## 📝 Credential Files

### GitHub Personal Access Token
```bash
# Create token at: https://github.com/settings/tokens
# Scopes needed: repo, workflow, read:packages

echo "ghp_your_token_here" > github-token
chmod 600 github-token
```

### Container Registry Authentication
```bash
# Authenticate with Podman/Docker
podman login ghcr.io
# Then copy the auth file
cp ~/.config/containers/auth.json registry-auth.json
chmod 600 registry-auth.json
```

### SSH Keys for Private Repositories
```bash
# Copy existing SSH key
cp ~/.ssh/id_ed25519 ssh-keys/
cp ~/.ssh/id_ed25519.pub ssh-keys/
chmod 600 ssh-keys/id_ed25519
chmod 644 ssh-keys/id_ed25519.pub

# Or generate new key
ssh-keygen -t ed25519 -f ssh-keys/id_ed25519 -C "mios-build"
```

### Secure Boot MOK (Machine Owner Key)
```bash
# Copy existing MOK key
cp /path/to/mok-key.priv mok-key.priv
cp /path/to/mok-cert.pem mok-cert.pem
chmod 600 mok-key.priv
chmod 644 mok-cert.pem

# Or generate new MOK key
../../tools/generate-mok-key.sh
mv MOK.priv mok-key.priv
mv MOK.pem mok-cert.pem
```

## 🔒 Security Best Practices

1. **Never commit credentials to git** (this directory is gitignored)
2. **Use appropriate file permissions** (600 for private keys, 644 for public)
3. **Rotate credentials regularly** (GitHub tokens expire, change passwords)
4. **Use environment-specific credentials** (different tokens for dev/prod)
5. **Back up credentials securely** (encrypted backup, password manager)

## 🗂️  Credential File Reference

| File | Purpose | Permissions |
|------|---------|-------------|
| `github-token` | GitHub PAT for repo access | 600 |
| `registry-auth.json` | Container registry auth | 600 |
| `ssh-keys/id_ed25519` | SSH private key | 600 |
| `ssh-keys/id_ed25519.pub` | SSH public key | 644 |
| `mok-key.priv` | Secure Boot MOK private key | 600 |
| `mok-cert.pem` | Secure Boot MOK certificate | 644 |

---

**Location:** `$XDG_CONFIG_HOME/mios/credentials/`
**Default:** `~/.config/mios/credentials/`
EOF
success "Created: credentials/README.md"

# Create SSH keys directory README
cat > "${MIOS_CONFIG_DIR}/credentials/ssh-keys/.gitkeep" <<'EOF'
# SSH Keys Directory
# Store SSH private/public key pairs here for accessing private repositories
EOF
success "Created: credentials/ssh-keys/.gitkeep"

echo ""
info "Creating quick reference guide..."

# Create quick reference in config directory
cat > "${MIOS_CONFIG_DIR}/README.md" <<EOF
# MiOS User Configuration

**Location:** \`${MIOS_CONFIG_DIR}\`

This directory contains your personal MiOS configuration files. These settings override system defaults and are **not** committed to version control.

## 📁 Directory Structure

\`\`\`
${MIOS_CONFIG_DIR}/
├── env.toml           # Environment configuration
├── images.toml        # OCI image references
├── build.toml         # Build configuration
├── flatpaks.list      # Flatpak applications
├── credentials/       # Sensitive data (gitignored)
│   ├── github-token
│   ├── registry-auth.json
│   └── ssh-keys/
└── README.md          # This file
\`\`\`

## 🚀 Quick Start

1. **Edit your environment:**
   \`\`\`bash
   \$EDITOR ${MIOS_CONFIG_DIR}/env.toml
   \`\`\`

2. **Customize OCI images:**
   \`\`\`bash
   \$EDITOR ${MIOS_CONFIG_DIR}/images.toml
   \`\`\`

3. **Configure build options:**
   \`\`\`bash
   \$EDITOR ${MIOS_CONFIG_DIR}/build.toml
   \`\`\`

4. **Add Flatpak applications:**
   \`\`\`bash
   \$EDITOR ${MIOS_CONFIG_DIR}/flatpaks.list
   \`\`\`

5. **Add credentials:**
   \`\`\`bash
   # GitHub token
   echo "ghp_your_token" > ${MIOS_CONFIG_DIR}/credentials/github-token
   chmod 600 ${MIOS_CONFIG_DIR}/credentials/github-token
   \`\`\`

## 🔧 Configuration Files

### env.toml
Environment configuration including:
- User name and hostname
- Build preferences (parallel jobs, cache, verbosity)
- Logging settings
- Path overrides

### images.toml
OCI image references including:
- Base image selection (NVIDIA, AMD, Intel variants)
- BIB (Bootc Image Builder) image
- Output image name and tags
- Registry configuration and mirrors

### build.toml
Build configuration including:
- Artifact types (QCOW2, ISO, RAW, etc.)
- Flatpak applications
- GPU support (NVIDIA, AMD, Intel)
- Kernel and bootloader settings
- User accounts and passwords

### flatpaks.list
One Flatpak application per line:
\`\`\`
org.mozilla.firefox
com.visualstudio.code
org.blender.Blender
\`\`\`

## 🌐 XDG Base Directories

MiOS follows XDG standards for user files:

| Purpose | Path |
|---------|------|
| Configuration | \`${MIOS_CONFIG_DIR}\` |
| Data | \`${MIOS_DATA_DIR}\` |
| Cache | \`${MIOS_CACHE_DIR}\` |
| State (logs) | \`${MIOS_STATE_DIR}\` |
| Runtime | \`${MIOS_RUNTIME_DIR}\` |

## 🔄 Configuration Priority

Variables are loaded in order (later overrides earlier):

1. System defaults (\`/usr/share/mios/config/\`)
2. **User configuration** (this directory) ⬅ You are here
3. Environment variables (\`MIOS_*\`)
4. Command-line arguments (highest priority)

## 📚 Documentation

- [User-Space Separation Spec](https://github.com/Kabuki94/MiOS-bootstrap/blob/main/specs/engineering/2026-04-27-Artifact-ENG-008-UserSpace-Separation.md)
- [System Templates](https://github.com/Kabuki94/MiOS-bootstrap/tree/main/etc/mios/templates)
- [Self-Build Guide](https://github.com/Kabuki94/MiOS-bootstrap/blob/main/SELF-BUILD.md)

---

**Generated:** $(date -u +%Y-%m-%dT%H:%M:%SZ)
**MiOS Version:** v0.1.3
EOF
success "Created: README.md"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                  ✅ Initialization Complete                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

info "User-space directories created:"
echo "   📁 Config:  ${MIOS_CONFIG_DIR}"
echo "   📁 Data:    ${MIOS_DATA_DIR}"
echo "   📁 Cache:   ${MIOS_CACHE_DIR}"
echo "   📁 State:   ${MIOS_STATE_DIR}"
if [[ -d "$MIOS_RUNTIME_DIR" ]]; then
    echo "   📁 Runtime: ${MIOS_RUNTIME_DIR}"
fi

echo ""
info "Configuration files copied:"
echo "   📝 env.toml"
echo "   📝 images.toml"
echo "   📝 build.toml"
echo "   📝 flatpaks.list"

echo ""
info "Next steps:"
echo ""
echo "   1. Customize your configuration:"
echo "      ${BLUE}\$EDITOR ${MIOS_CONFIG_DIR}/env.toml${NC}"
echo ""
echo "   2. Set your preferred base image:"
echo "      ${BLUE}\$EDITOR ${MIOS_CONFIG_DIR}/images.toml${NC}"
echo ""
echo "   3. Configure build options:"
echo "      ${BLUE}\$EDITOR ${MIOS_CONFIG_DIR}/build.toml${NC}"
echo ""
echo "   4. Add credentials (GitHub, container registry):"
echo "      ${BLUE}echo \"ghp_token\" > ${MIOS_CONFIG_DIR}/credentials/github-token${NC}"
echo "      ${BLUE}chmod 600 ${MIOS_CONFIG_DIR}/credentials/github-token${NC}"
echo ""
echo "   5. Build MiOS with your configuration:"
echo "      ${BLUE}just build${NC}"
echo ""

success "User-space initialization complete!"
echo ""
