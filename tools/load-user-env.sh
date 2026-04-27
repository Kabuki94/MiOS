#!/usr/bin/env bash
# MiOS User Environment Loader
# Loads user configuration from XDG-compliant TOML files and exports as environment variables
#
# Priority order (later overrides earlier):
#   1. System defaults (/usr/share/mios/config/ or etc/mios/templates/)
#   2. User configuration ($XDG_CONFIG_HOME/mios/)
#   3. Environment variables (already set)
#   4. Command-line arguments (handled by Justfile)
#
# Usage: source ./tools/load-user-env.sh
#        (or: eval "$(./tools/load-user-env.sh)")

set -euo pipefail

# XDG Base Directory variables with fallback defaults
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# MiOS-specific XDG paths
export MIOS_CONFIG_DIR="${XDG_CONFIG_HOME}/mios"
export MIOS_DATA_DIR="${XDG_DATA_HOME}/mios"
export MIOS_CACHE_DIR="${XDG_CACHE_HOME}/mios"
export MIOS_STATE_DIR="${XDG_STATE_HOME}/mios"
export MIOS_RUNTIME_DIR="${XDG_RUNTIME_DIR}/mios"

# Repository root (for system defaults)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYSTEM_TEMPLATE_DIR="${REPO_ROOT}/etc/mios/templates"

# Simple TOML parser for key="value" format
# Converts TOML sections and keys to environment variables
# Example: [images] base = "foo" → MIOS_IMAGES_BASE="foo"
parse_toml() {
    local toml_file="$1"
    local prefix="${2:-MIOS}"

    if [[ ! -f "$toml_file" ]]; then
        return 0
    fi

    local section=""
    local line_num=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))

        # Remove comments
        line="${line%%#*}"

        # Trim whitespace
        line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

        # Skip empty lines
        [[ -z "$line" ]] && continue

        # Section header: [section]
        if [[ "$line" =~ ^\[([a-zA-Z0-9_]+)\]$ ]]; then
            section="${BASH_REMATCH[1]}"
            continue
        fi

        # Section with dots: [section.subsection]
        if [[ "$line" =~ ^\[([a-zA-Z0-9_\.]+)\]$ ]]; then
            section="${BASH_REMATCH[1]}"
            section="${section//./_}"  # Replace dots with underscores
            continue
        fi

        # Key-value pair: key = "value" or key = value
        if [[ "$line" =~ ^([a-zA-Z0-9_]+)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # Remove quotes from value
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"

            # Convert boolean lowercase to uppercase for shell
            case "$value" in
                true) value="true" ;;
                false) value="false" ;;
            esac

            # Build environment variable name
            local var_name="${prefix}"
            if [[ -n "$section" ]]; then
                var_name="${var_name}_${section}"
            fi
            var_name="${var_name}_${key}"
            var_name="$(echo "$var_name" | tr '[:lower:]' '[:upper:]')"

            # Export variable
            export "${var_name}=${value}"
        fi
    done < "$toml_file"
}

# Load system defaults first
if [[ -f "${SYSTEM_TEMPLATE_DIR}/default.env.toml" ]]; then
    parse_toml "${SYSTEM_TEMPLATE_DIR}/default.env.toml" "MIOS"
fi

if [[ -f "${SYSTEM_TEMPLATE_DIR}/default.images.toml" ]]; then
    parse_toml "${SYSTEM_TEMPLATE_DIR}/default.images.toml" "MIOS"
fi

if [[ -f "${SYSTEM_TEMPLATE_DIR}/default.build.toml" ]]; then
    parse_toml "${SYSTEM_TEMPLATE_DIR}/default.build.toml" "MIOS"
fi

# Load user configuration (overrides system defaults)
if [[ -f "${MIOS_CONFIG_DIR}/env.toml" ]]; then
    parse_toml "${MIOS_CONFIG_DIR}/env.toml" "MIOS"
fi

if [[ -f "${MIOS_CONFIG_DIR}/images.toml" ]]; then
    parse_toml "${MIOS_CONFIG_DIR}/images.toml" "MIOS"
fi

if [[ -f "${MIOS_CONFIG_DIR}/build.toml" ]]; then
    parse_toml "${MIOS_CONFIG_DIR}/build.toml" "MIOS"
fi

# Map parsed variables to legacy environment variable names for compatibility
# This allows existing build scripts to work without modification

# Base image (from images.toml [base] image)
export MIOS_BASE_IMAGE="${MIOS_BASE_IMAGE:-${MIOS_BASE_IMAGE:-${MIOS_IMAGES_BASE_IMAGE:-ghcr.io/ublue-os/ucore-hci:stable-nvidia}}}"

# BIB image (from images.toml [builder] image)
export MIOS_BIB_IMAGE="${MIOS_BIB_IMAGE:-${MIOS_BUILDER_IMAGE:-${MIOS_IMAGES_BUILDER_IMAGE:-quay.io/centos-bootc/bootc-image-builder:latest}}}"

# Output image name (from images.toml [output] name)
export MIOS_IMAGE_NAME="${MIOS_IMAGE_NAME:-${MIOS_OUTPUT_NAME:-${MIOS_IMAGES_OUTPUT_NAME:-localhost/mios}}}"

# User name (from env.toml [mios] user)
export MIOS_USER="${MIOS_USER:-${MIOS_MIOS_USER:-mios}}"

# Hostname (from env.toml [mios] hostname)
export MIOS_HOSTNAME="${MIOS_HOSTNAME:-${MIOS_MIOS_HOSTNAME:-mios}}"

# Flatpaks source file (from build.toml [flatpaks] source_file)
if [[ -n "${MIOS_FLATPAKS_SOURCE_FILE:-}" ]] && [[ -f "${MIOS_FLATPAKS_SOURCE_FILE}" ]]; then
    # Read flatpaks.list and convert to comma-separated list
    MIOS_FLATPAKS="$(grep -v '^#' "${MIOS_FLATPAKS_SOURCE_FILE}" | grep -v '^$' | tr '\n' ' ' | sed 's/ $//')"
    export MIOS_FLATPAKS
elif [[ -f "${MIOS_CONFIG_DIR}/flatpaks.list" ]]; then
    MIOS_FLATPAKS="$(grep -v '^#' "${MIOS_CONFIG_DIR}/flatpaks.list" | grep -v '^$' | tr '\n' ' ' | sed 's/ $//')"
    export MIOS_FLATPAKS
else
    export MIOS_FLATPAKS="${MIOS_FLATPAKS:-}"
fi

# Log directory (from env.toml [logging] log_dir)
if [[ -n "${MIOS_LOGGING_LOG_DIR:-}" ]]; then
    export MIOS_LOG_DIR="${MIOS_LOGGING_LOG_DIR}"
else
    export MIOS_LOG_DIR="${MIOS_STATE_DIR}/logs"
fi

# Create log directory if it doesn't exist
mkdir -p "${MIOS_LOG_DIR}"

# Set build cache directory
export MIOS_BUILD_CACHE_DIR="${MIOS_CACHE_DIR}/build-cache"
mkdir -p "${MIOS_BUILD_CACHE_DIR}"

# Debug output (if MIOS_DEBUG=true)
if [[ "${MIOS_DEBUG:-false}" == "true" ]]; then
    echo "=== MiOS Environment Variables ===" >&2
    env | grep '^MIOS_' | sort >&2
    echo "===================================" >&2
fi

# If running as a script (not sourced), print export statements
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    env | grep '^MIOS_' | sort | sed 's/^/export /'
fi
