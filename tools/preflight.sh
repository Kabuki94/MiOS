#!/usr/bin/env bash
# MiOS Preflight (Linux)
# Comprehensive system check and prerequisite installer.
# Maps user environment and ensures all flight systems are READY.

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "+===========================================================================+"
echo "|                          MIOS PREFLIGHT CHECK                             |"
echo "+===========================================================================+"
echo -e "${NC}"

PASS=0
FAIL=0
FIXED=0

check_app() {
    local cmd="$1"
    local name="$2"
    local install_cmd="${3:-}"

    printf "  [ ] Checking %-20s " "${name}..."
    if command -v "$cmd" &>/dev/null; then
        echo -e "${GREEN}[OK]${NC}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}[MISSING]${NC}"
        FAIL=$((FAIL + 1))
        if [[ -n "$install_cmd" ]]; then
            echo -e "      ${YELLOW}Suggestion:${NC} Install with: ${install_cmd}"
        fi
    fi
}

echo -e "${YELLOW}--- Core Toolchain ---${NC}"
check_app "git" "Git" "sudo dnf install -y git"
check_app "podman" "Podman" "sudo dnf install -y podman"
check_app "just" "Just" "sudo dnf install -y just"
check_app "python3" "Python 3" "sudo dnf install -y python3"
check_app "rsync" "Rsync" "sudo dnf install -y rsync"
echo ""

echo -e "${YELLOW}--- System Environment ---${NC}"
if [[ -f "/etc/fedora-release" ]]; then
    echo -e "  [OK] OS: $(cat /etc/fedora-release)"
    PASS=$((PASS + 1))
else
    echo -e "  [WARN] Non-Fedora system detected. Some build scripts may require adjustment."
fi

# Check for User-Space Initialization
if [[ -d "${XDG_CONFIG_HOME:-$HOME/.config}/mios" ]]; then
    echo -e "  [OK] User-Space: Initialized"
    PASS=$((PASS + 1))
else
    echo -e "  [WARN] User-Space: NOT INITIALIZED. Run 'just init-user-space'."
    FAIL=$((FAIL + 1))
fi

# Check disk space
FREE_GB=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
if [[ $FREE_GB -ge 20 ]]; then
    echo -e "  [OK] Disk Space: ${FREE_GB}GB free"
    PASS=$((PASS + 1))
else
    echo -e "  [WARN] Low disk space: ${FREE_GB}GB free (20GB recommended)"
fi
echo ""

echo -e "${CYAN}--- Summary ---${NC}"
echo -e "  Passed:  ${GREEN}${PASS}${NC}"
echo -e "  Failed:  ${RED}${FAIL}${NC}"
echo ""

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}SYSTEM READY FOR FLIGHT.${NC}"
    exit 0
else
    echo -e "${YELLOW}PREFLIGHT HAD WARNINGS/FAILURES. RESOLVE BEFORE BUILDING.${NC}"
    exit 1
fi
