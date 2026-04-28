#!/usr/bin/env bash
# MiOS Unified Initialization Script
# Handles bootstrapping, system deployment, and user-space setup.
# Verbs: live-init, deploy, init-user-space

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

VERB="${1:-help}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

info() { echo -e "${BLUE}  ${NC}$*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]  ${NC}$*"; }
error() { echo -e "${RED}[FAIL]${NC} $*" >&2; }

show_help() {
    echo ""
    echo "  MiOS Unified Initialization"
    echo "  ==========================="
    echo ""
    echo "  USAGE: mios-init <verb> [options]"
    echo ""
    echo "  VERBS:"
    echo "    live-init       [Mode 0] Overlay repository onto Live ISO root (folder merge only)"
    echo "    deploy          [Mode 1] Install to system FHS directories (/usr/src/mios, /etc/mios)"
    echo "    user            [Mode 2] Initialize user-space configuration (~/.config/mios)"
    echo "    help            Show this help"
    echo ""
}

# [Mode 0] Live ISO Initiation
# Clones and overlays the MiOS repository onto the live system's root.
# Constraint: folder merges only, no overwrites to system files.
do_live_init() {
    echo ""
    echo "+---------------------------------------------------------------------------+"
    echo "| MiOS Mode 0: Live ISO Initiation                                          |"
    echo "+---------------------------------------------------------------------------+"
    echo ""

    if [[ $EUID -ne 0 ]]; then
        error "Live initiation requires root privileges (sudo)."
        exit 1
    fi

    info "Identifying Live Environment..."
    if [[ ! -f "/etc/fedora-release" ]]; then
        warn "Non-Fedora environment detected. Live initiation optimized for Fedora Server Live ISO."
    fi

    # 1. Ensure git is available
    if ! command -v git &>/dev/null; then
        info "Installing git for initiation..."
        dnf install -y git || { error "Failed to install git. Network available?"; exit 1; }
    fi

    # 2. Setup temporary initiation path
    INIT_DIR="/tmp/mios-init"
    mkdir -p "$INIT_DIR"
    
    info "Cloning MiOS repository..."
    git clone --depth 1 https://github.com/Kabuki94/MiOS-bootstrap.git "$INIT_DIR"

    # 3. Overlay onto system root
    # --ignore-existing ensures we ONLY merge folders and add new files.
    # We DO NOT overwrite existing system files (like /etc/passwd, etc.)
    info "Overlaying MiOS repository onto system root (folder merge only)..."
    
    # Folders to overlay
    for dir in "usr" "etc" "var" "home"; do
        if [[ -d "${INIT_DIR}/${dir}" ]]; then
            info "Merging /${dir}..."
            rsync -av --ignore-existing "${INIT_DIR}/${dir}/" "/${dir}/"
        fi
    done

    # 4. Setup operational symlink
    info "Linking MiOS command..."
    ln -sf "${INIT_DIR}/usr/bin/mios" "/usr/local/bin/mios"
    
    # 5. Run system-level deployment (linking FHS paths)
    info "Finalizing system deployment..."
    export INSTALL_PREFIX="/usr"
    export MIOS_SRC_DIR="$INIT_DIR"
    bash "${INIT_DIR}/install.sh" --no-clone

    success "Live ISO Initiation Complete."
    echo ""
    echo "  You can now run 'mios' directly from the terminal."
    echo "  Next Step: mios user"
    echo ""
}

# [Mode 1] System-Wide Deployment
do_deploy() {
    bash "${REPO_ROOT}/install.sh"
}

# [Mode 2] User-Space Initialization
do_user_init() {
    bash "${REPO_ROOT}/tools/init-user-space.sh"
}

case "$VERB" in
    live-init) do_live_init ;;
    deploy)    do_deploy ;;
    user)      do_user_init ;;
    help|--help|-h) show_help ;;
    *)
        error "Unknown verb: $VERB"
        show_help
        exit 1
        ;;
esac
