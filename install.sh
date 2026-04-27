#!/usr/bin/env bash
# MiOS Bootstrap Installer
# Deploys the MiOS repository as a Linux filesystem-native integrated build environment
#
# Usage: sudo ./install.sh [--uninstall]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Installation paths (FHS 3.0)
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr}"
MIOS_SHARE_DIR="${INSTALL_PREFIX}/share/mios"
MIOS_ETC_DIR="/etc/mios"
MIOS_VAR_LIB_DIR="/var/lib/mios"
MIOS_VAR_LOG_DIR="/var/log/mios"
MIOS_BIN_DIR="/usr/local/bin"
MIOS_TMPFILES_DIR="/etc/tmpfiles.d"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info() { echo -e "${BLUE}ℹ️  ${NC}$*"; }
success() { echo -e "${GREEN}✅${NC} $*"; }
warn() { echo -e "${YELLOW}⚠️  ${NC}$*"; }
error() { echo -e "${RED}❌${NC} $*" >&2; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_prerequisites() {
    local missing=()
    command -v git >/dev/null 2>&1 || missing+=("git")
    command -v podman >/dev/null 2>&1 || missing+=("podman")
    command -v just >/dev/null 2>&1 || missing+=("just")

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required packages: ${missing[*]}"
        echo "Install with: sudo dnf install -y ${missing[*]}"
        exit 1
    fi
}

install_mios() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           MiOS Bootstrap Installer (FHS Native)             ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    info "Creating FHS directory structure..."
    mkdir -p "${MIOS_SHARE_DIR}" "${MIOS_ETC_DIR}" "${MIOS_BIN_DIR}" "${MIOS_TMPFILES_DIR}"
    success "Created system directories"

    info "Installing to ${MIOS_SHARE_DIR}..."
    rsync -a --exclude='.git' --exclude='output/' --exclude='*.qcow2' --exclude='*.iso' \
        "${REPO_ROOT}/" "${MIOS_SHARE_DIR}/"
    success "Installed application data"

    info "Installing configuration to ${MIOS_ETC_DIR}..."
    cp -r "${REPO_ROOT}/etc/mios/templates" "${MIOS_ETC_DIR}/"
    
    cat > "${MIOS_ETC_DIR}/manifest.json" <<EOF
{
  "mios_version": "$(cat ${REPO_ROOT}/VERSION 2>/dev/null || echo 'v0.1.3')",
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "paths": {
    "share": "${MIOS_SHARE_DIR}",
    "etc": "${MIOS_ETC_DIR}",
    "var_lib": "${MIOS_VAR_LIB_DIR}",
    "var_log": "${MIOS_VAR_LOG_DIR}"
  }
}
EOF
    success "Installed system configuration"

    info "Creating tmpfiles.d configuration..."
    cat > "${MIOS_TMPFILES_DIR}/mios.conf" <<'EOF'
d /var/lib/mios 0755 root root -
d /var/lib/mios/artifacts 0755 root root -
d /var/lib/mios/snapshots 0755 root root -
d /var/log/mios 0755 root root -
d /var/log/mios/builds 0755 root root -
EOF
    systemd-tmpfiles --create "${MIOS_TMPFILES_DIR}/mios.conf"
    success "Created /var directories"

    info "Installing mios command..."
    cat > "${MIOS_BIN_DIR}/mios" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
MIOS_INSTALL_DIR="/usr/share/mios"
if [[ ! -d "$MIOS_INSTALL_DIR" ]]; then
    echo "❌ MiOS not installed" >&2
    exit 1
fi
cd "$MIOS_INSTALL_DIR"
exec just "$@"
EOF
    chmod +x "${MIOS_BIN_DIR}/mios"
    success "Installed mios command"

    chmod -R a+rX "${MIOS_SHARE_DIR}"
    chown -R root:root "${MIOS_ETC_DIR}"

    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              ✅ MiOS Installation Complete                   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    info "Next steps:"
    echo "  1. Initialize user-space: ${CYAN}mios init-user-space${NC}"
    echo "  2. Configure: ${CYAN}mios edit-env${NC}"
    echo "  3. Build: ${CYAN}mios build${NC}"
    echo ""
}

uninstall_mios() {
    warn "This will remove MiOS from system directories."
    read -p "Continue? [y/N] " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0

    [[ -d "${MIOS_SHARE_DIR}" ]] && rm -rf "${MIOS_SHARE_DIR}" && success "Removed ${MIOS_SHARE_DIR}"
    [[ -d "${MIOS_ETC_DIR}" ]] && rm -rf "${MIOS_ETC_DIR}" && success "Removed ${MIOS_ETC_DIR}"
    [[ -f "${MIOS_BIN_DIR}/mios" ]] && rm -f "${MIOS_BIN_DIR}/mios" && success "Removed mios command"
    [[ -f "${MIOS_TMPFILES_DIR}/mios.conf" ]] && rm -f "${MIOS_TMPFILES_DIR}/mios.conf"
    success "MiOS uninstalled"
}

main() {
    [[ "${1:-}" == "--uninstall" ]] && { check_root; uninstall_mios; exit 0; }
    check_root
    check_prerequisites
    install_mios
}

main "$@"
