#!/usr/bin/env bash
# ============================================================================
# scripts/05-enable-external-repos.sh
# ----------------------------------------------------------------------------
# Enable external DNF repositories for CloudWS-bootc (Fedora 44 / Rawhide).
# Idempotent; fails fast; uses ${DNF_SETOPT[@]} from scripts/lib/common.sh.
# RPM Fusion is intentionally NOT handled here — see 01-repos.sh.
#
# v2.1.6 CHANGES:
#   - removed redundant RPM Fusion install block (was using `rpm -E %fedora`
#     which yielded 41/43 from the base image and clobbered 01-repos.sh's
#     explicit F44 pin).
#   - replaced dnf5 with dnf throughout (consistency with 01-repos.sh and
#     lib/packages.sh; on F44 `dnf` is dnf5 via symlink anyway).
#   - adopted ${DNF_SETOPT[@]} for every mutating invocation.
# ============================================================================
set -euo pipefail

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

REPO_DIR=/etc/yum.repos.d

# --- 1. Terra (fyralabs) ----------------------------------------------------
# Patched WINE/Mesa/miscellaneous packages missing from Fedora + RPM Fusion.
if [[ ! -f "${REPO_DIR}/terra.repo" ]]; then
    log "enabling Terra repo (fyralabs)"
    curl -fsSL \
        https://github.com/terrapkg/subatomic-repos/raw/main/terra.repo \
        -o "${REPO_DIR}/terra.repo"
else
    log "Terra repo already present — skipping"
fi

# --- 2. Visual Studio Code (Microsoft) --------------------------------------
if [[ ! -f "${REPO_DIR}/vscode.repo" ]]; then
    log "enabling VS Code repo (Microsoft)"
    rpm --import https://packages.microsoft.com/keys/microsoft.asc
    cat > "${REPO_DIR}/vscode.repo" <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
else
    log "VS Code repo already present — skipping"
fi

# --- 3. 1Password -----------------------------------------------------------
if [[ ! -f "${REPO_DIR}/1password.repo" ]]; then
    log "enabling 1Password repo"
    rpm --import https://downloads.1password.com/linux/keys/1password.asc
    cat > "${REPO_DIR}/1password.repo" <<'EOF'
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
EOF
else
    log "1Password repo already present — skipping"
fi

# --- 4. Tailscale -----------------------------------------------------------
if [[ ! -f "${REPO_DIR}/tailscale.repo" ]]; then
    log "enabling Tailscale repo"
    dnf "${DNF_SETOPT[@]}" -y config-manager addrepo \
        --overwrite \
        --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
else
    log "Tailscale repo already present — skipping"
fi

# --- 5. Docker CE (required when podman-docker is removed) ------------------
if [[ ! -f "${REPO_DIR}/docker-ce.repo" ]]; then
    log "enabling Docker CE repo"
    dnf "${DNF_SETOPT[@]}" -y config-manager addrepo \
        --overwrite \
        --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
else
    log "Docker CE repo already present — skipping"
fi

# --- 6. Google Chrome -------------------------------------------------------
if [[ ! -f "${REPO_DIR}/google-chrome.repo" ]]; then
    log "enabling Google Chrome repo"
    rpm --import https://dl.google.com/linux/linux_signing_key.pub
    cat > "${REPO_DIR}/google-chrome.repo" <<'EOF'
[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/$basearch
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF
else
    log "Google Chrome repo already present — skipping"
fi

log "external repos enabled; refreshing metadata"
dnf "${DNF_SETOPT[@]}" -y makecache

log "05-enable-external-repos.sh complete"
