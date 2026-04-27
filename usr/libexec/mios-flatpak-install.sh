#!/bin/bash
# MiOS v0.1.3 — Flatpak First-Boot Installer
# Dictated by global environment and user space profiles.
set -euo pipefail

# Suppress DBus/dconf warnings in headless automation/early-boot environments
export GIO_USE_VFS=local
export GSETTINGS_BACKEND=memory

VER=4
VER_FILE="/etc/mios/.flatpak-version"
SCRIPT_HASH=$(sha256sum "$0" | cut -d' ' -f1)
VER_RUN="${VER}-${SCRIPT_HASH}"
LOG="/var/log/mios-flatpak-install.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

if [ -f "$VER_FILE" ] && [ "$(cat "$VER_FILE")" = "$VER_RUN" ]; then
    log "Already at version ${VER}"; exit 0
fi

mkdir -p /etc/mios
log "MiOS Flatpak installer v${VER}"

# 1. Source System-Baked Environment Definitions (/usr/lib/mios/env.d/)
# Priority: User-defined build args captured in system usr folders
SYSTEM_ENV="/usr/lib/mios/env.d/flatpaks.env"
if [ -f "$SYSTEM_ENV" ]; then
    log "Loading system environment from $SYSTEM_ENV..."
    # shellcheck disable=SC1091
    source "$SYSTEM_ENV"
fi

# 2. Configure Remotes
log "Configuring Flatpak remotes..."
flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>&1 | tee -a "$LOG" || true
flatpak remote-modify --system --disable fedora 2>&1 | tee -a "$LOG" || true
flatpak remote-modify --system --disable fedora-testing 2>&1 | tee -a "$LOG" || true

# 3. Aggregate Flatpak Lists
# Priority: 
#   A. USER_SPACE (~/.config/mios/flatpaks.list)
#   B. USER_ENV (~/.env.mios)
#   C. SYSTEM_ENV_VARS (from /usr/lib/mios/env.d/*.env)
#   D. SYSTEM_DEFAULT (/usr/share/mios/flatpak-list)

FINAL_LIST=$(mktemp)

# Check all real user home directories for user-space profiles
while IFS=: read -r _ _ uid _ _ home _; do
    if [ "$uid" -ge 1000 ] && [ "$uid" -lt 65000 ] && [ -d "$home" ]; then
        # A. Check for flatpaks.list
        USER_LIST="${home}/.config/mios/flatpaks.list"
        if [ -f "$USER_LIST" ]; then
            log "  Found user list: $USER_LIST"
            grep -v '^#' "$USER_LIST" | grep -v '^$' >> "$FINAL_LIST"
        fi

        # B. Check for .env.mios (Native Linux user-space env file)
        USER_ENV_FILE="${home}/.env.mios"
        if [ -f "$USER_ENV_FILE" ]; then
            log "  Found user env: $USER_ENV_FILE"
            U_FLATPAKS=$(grep "^MIOS_FLATPAKS=" "$USER_ENV_FILE" | cut -d= -f2- | sed 's/^["'\'']//;s/["'\'']$//' || true)
            if [ -n "$U_FLATPAKS" ]; then
                log "    Adding Flatpaks from user env..."
                echo "$U_FLATPAKS" | tr ',' '\n' >> "$FINAL_LIST"
            fi
        fi
    fi
done < /etc/passwd

# C. Add system environment variables (from venv/env style files in /usr)
if [ -n "${MIOS_FLATPAKS:-}" ]; then
    log "  Adding Flatpaks from system env profile..."
    echo "$MIOS_FLATPAKS" | tr ',' '\n' >> "$FINAL_LIST"
fi

# D. Add system defaults
SYSTEM_LIST="/usr/share/mios/flatpak-list"
if [ -f "$SYSTEM_LIST" ]; then
    log "  Adding Flatpaks from system default: $SYSTEM_LIST"
    grep -v '^#' "$SYSTEM_LIST" | grep -v '^$' >> "$FINAL_LIST"
fi

# Deduplicate
sort -u "$FINAL_LIST" -o "$FINAL_LIST"

# 4. Install
if [ -s "$FINAL_LIST" ]; then
    log "Installing $(wc -l < "$FINAL_LIST") unique Flatpaks..."
    while IFS= read -r app || [ -n "$app" ]; do
        [[ -z "$app" || "$app" == \#* ]] && continue
        log "  -> ${app}"
        flatpak install -y --noninteractive --system flathub "$app" 2>&1 | tee -a "$LOG" || log "  WARN: ${app} failed"
    done < "$FINAL_LIST"
else
    log "No Flatpaks defined for installation."
fi

rm -f "$FINAL_LIST"

# 5. Global Overrides
log "Applying global Flatpak overrides..."
flatpak override --system --filesystem=xdg-config/gtk-3.0:ro 2>&1 | tee -a "$LOG" || true
flatpak override --system --filesystem=xdg-config/gtk-4.0:ro 2>&1 | tee -a "$LOG" || true
flatpak override --system --env=GTK_THEME=adw-gtk3-dark 2>&1 | tee -a "$LOG" || true

echo "$VER_RUN" > "$VER_FILE"
log "Complete"
