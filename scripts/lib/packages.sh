#!/bin/bash
# CloudWS — Package extraction library
# Parses PACKAGES.md fenced code blocks tagged with ```packages-<category>
#
# Usage:
#   source scripts/lib/packages.sh
#   PACKAGES=$(get_packages "gnome" "/path/to/PACKAGES.md")
#   dnf -y install $PACKAGES

get_packages() {
    local category="$1"
    local packages_file="${2:-${PACKAGES_MD:-/tmp/build/PACKAGES.md}}"

    if [[ ! -f "$packages_file" ]]; then
        echo "[packages.sh] ERROR: $packages_file not found" >&2
        return 1
    fi

    # Extract lines between ```packages-<category> and ``` markers
    # Skips blank lines and comments (lines starting with #)
    sed -n "/^\`\`\`packages-${category}$/,/^\`\`\`$/{/^\`\`\`/d;/^$/d;/^#/d;p}" "$packages_file" \
        | tr '\n' ' '
}

get_packages_strict() {
    # Same as get_packages but fails the build if section is empty
    local result
    result=$(get_packages "$@")
    if [[ -z "$result" ]]; then
        echo "[packages.sh] ERROR: No packages found in section '$1'" >&2
        return 1
    fi
    echo "$result"
}

install_packages() {
    local category="$1"
    local packages_file="${2:-${PACKAGES_MD:-/tmp/build/PACKAGES.md}}"
    local packages
    packages=$(get_packages "$category" "$packages_file")
    if [[ -n "$packages" ]]; then
        echo "[packages.sh] Installing '$category' packages..."
        dnf -y install --skip-unavailable $packages
    else
        echo "[packages.sh] WARN: No packages in section '$category' — skipping"
    fi
}

install_packages_strict() {
    local category="$1"
    local packages_file="${2:-${PACKAGES_MD:-/tmp/build/PACKAGES.md}}"
    local packages
    packages=$(get_packages_strict "$category" "$packages_file") || return 1
    echo "[packages.sh] Installing '$category' packages (strict)..."
    dnf -y install $packages
}
