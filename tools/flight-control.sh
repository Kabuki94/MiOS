#!/usr/bin/env bash
# MiOS Flight Control (Pre-build Diagnostics)
# Displays current build configuration, environment mappings, and flight status.
# Maps user-space variables to mutable/immutable transience during build-time.

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Source environment
source ./tools/load-user-env.sh

echo -e "${CYAN}"
echo "+===========================================================================+"
echo "|                          MIOS FLIGHT CONTROL                              |"
echo "+===========================================================================+"
echo -e "${NC}"

# -- USER-SPACE MAPPING ------------------------------------------------------
echo -e "${YELLOW}[DIR] User-Space Mappings (XDG Native)${NC}"
printf "  %-20s %s\n" "Config:" "${MIOS_CONFIG_DIR}"
printf "  %-20s %s\n" "Data:"   "${MIOS_DATA_DIR}"
printf "  %-20s %s\n" "Cache:"  "${MIOS_CACHE_DIR}"
printf "  %-20s %s\n" "State:"  "${MIOS_STATE_DIR}"
echo ""

# -- FLIGHT VARIABLES (MUTABLE) ----------------------------------------------
echo -e "${YELLOW}[VAR] Flight Variables (User-Set / Mutable)${NC}"
printf "  %-20s %s\n" "User:"     "${MIOS_USER}"
printf "  %-20s %s\n" "Hostname:" "${MIOS_HOSTNAME}"
printf "  %-20s %s\n" "Image:"    "${MIOS_IMAGE_NAME}"
printf "  %-20s %s\n" "Flatpaks:" "${MIOS_FLATPAKS:-(default system set)}"
echo ""

# -- SYSTEM TAGS (IMMUTABLE/TRACKED) -----------------------------------------
echo -e "${YELLOW}[TAG] System Tags (Immutable / Tracked)${NC}"
# Parse tags from registry.toml
if [[ -f "config/registry.toml" ]]; then
    while IFS= read -r line; do
        if [[ "$line" =~ ^\[tags\.([a-zA-Z0-9_]+)\]$ ]]; then
            tag_id="${BASH_REMATCH[1]}"
            # Look for value on the next line
            read -r val_line
            if [[ "$val_line" =~ value[[:space:]]*=[[:space:]]*\"(.*)\" ]]; then
                tag_val="${BASH_REMATCH[1]}"
                printf "  %-20s %s\n" "@${tag_id}:" "${tag_val}"
            fi
        fi
    done < "config/registry.toml"
fi
echo ""

# -- PREFLIGHT CHECKS --------------------------------------------------------
echo -e "${YELLOW}[CHK] Preflight Diagnostics${NC}"

check_cmd() {
    local cmd="$1"
    local desc="$2"
    printf "  %-20s " "${desc}:"
    if command -v "$cmd" &>/dev/null; then
        local ver=$($cmd --version 2>&1 | head -n 1)
        echo -e "${GREEN}[READY]${NC} ${ver}"
    else
        echo -e "${RED}[MISSING]${NC}"
    fi
}

check_cmd "podman" "Container Engine"
check_cmd "just"   "Build Runner"
check_cmd "git"    "Version Control"
check_cmd "python3" "Script Engine"

# Check for .venv
if [[ -d ".venv" ]] || [[ -d "${MIOS_DATA_DIR}/venv" ]]; then
    printf "  %-20s ${GREEN}[READY]${NC}\n" "Python Venv:"
else
    printf "  %-20s ${YELLOW}[NOT FOUND]${NC} (run 'just init-user-space')\n" "Python Venv:"
fi

# Check for credentials
if [[ -f "${MIOS_CONFIG_DIR}/credentials/github-token" ]]; then
    printf "  %-20s ${GREEN}[PRESENT]${NC}\n" "GitHub Token:"
else
    printf "  %-20s ${YELLOW}[MISSING]${NC}\n" "GitHub Token:"
fi

echo ""
echo -e "${CYAN}+===========================================================================+${NC}"
echo ""
