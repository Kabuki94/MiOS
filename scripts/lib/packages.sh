#!/bin/bash
# CloudWS v1.3 — Package extraction library
# Parses PACKAGES.md fenced code blocks tagged with ```packages-<category>
#
# Usage:
#   source scripts/lib/packages.sh
#   PACKAGES=$(get_packages "gnome" "/path/to/PACKAGES.md")
#   dnf -y install $PACKAGES

get_packages() {
    local category="$1"
    local packages_file="${2:-${PACKAGES_MD:-/ctx/PACKAGES.md}}"

    if [[ ! -f "$packages_file" ]]; then
        echo "[packages.sh] ERROR: $packages_file not found" >&2
        return 1
    fi

    sed -n "/^\`\`\`packages-${category}$/,/^\`\`\`$/{/^\`\`\`/d;/^$/d;/^#/d;p}" "$packages_file" \
        | tr '\n' ' '
}

get_packages_strict() {
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
    local packages_file="${2:-${PACKAGES_MD:-/ctx/PACKAGES.md}}"
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
    local packages_file="${2:-${PACKAGES_MD:-/ctx/PACKAGES.md}}"
    local packages
    packages=$(get_packages_strict "$category" "$packages_file") || return 1
    echo "[packages.sh] Installing '$category' packages (strict section)..."
    dnf -y install --skip-unavailable $packages
}

install_packages_optional() {
    local category="$1"
    local packages_file="${2:-${PACKAGES_MD:-/ctx/PACKAGES.md}}"

    # Check if section exists at all
    local raw_section
    raw_section=$(sed -n "/^\`\`\`packages-${category}$/,/^\`\`\`$/{/^\`\`\`/d;p}" "$packages_file")

    if [[ -z "$raw_section" ]]; then
        echo "[packages.sh] WARN: Section 'packages-${category}' not found — skipping"
        return 0
    fi

    # Check if ALL lines are comments (intentionally disabled)
    local uncommented
    uncommented=$(echo "$raw_section" | grep -v '^#' | grep -v '^$' || true)

    if [[ -z "$uncommented" ]]; then
        echo "[packages.sh] INFO: All packages in '${category}' are commented out (intentionally disabled)"
        return 0
    fi

    # Some packages are uncommented — install those
    local packages
    packages=$(get_packages "$category" "$packages_file")
    if [[ -n "$packages" ]]; then
        echo "[packages.sh] Installing optional '$category' packages..."
        dnf -y install --skip-unavailable $packages
    fi
}
