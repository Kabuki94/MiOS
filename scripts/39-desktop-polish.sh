#!/bin/bash
# CloudWS v1.3.0 — 39-desktop-polish: Desktop entries, Cockpit webapp, MOTD
#
# CHANGELOG v2.3.1:
#   - FIX: cloudws-motd source path was /tmp/build/scripts/ (never exists).
#     Scripts run from /ctx/scripts/ in the buildroot. The bogus path + the
#     `|| true` swallowed the failure silently, so /usr/libexec/cloudws-motd
#     was never created. profile.d/cloudws-motd.sh falls back to it when
#     fastfetch is missing, so terminal MOTD printed nothing on every
#     v2.0-v2.2 image.
#   - FIX: SCRIPT_DIR-relative copy so this works whether build.sh invokes
#     us from /ctx/scripts/ or any other future path. If the source is
#     missing, FAIL LOUDLY (remove the silencing `|| true`) so it can't
#     regress unnoticed.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[39-desktop-polish] Final desktop polish..."

# ═══ COCKPIT DESKTOP ENTRY — uses cockpit-desktop (no TLS warnings) ═══
echo "[39-desktop-polish] Cockpit desktop entry delivered via overlay."

# ═══ NVIDIA SETTINGS DESKTOP ENTRY ═══
echo "[39-desktop-polish] NVIDIA Settings desktop entry delivered via overlay."

# ═══ CEPH DASHBOARD — update to use correct app name ═══
echo "[39-desktop-polish] Ceph Dashboard desktop entry delivered via overlay."

# ═══ MOTD DASHBOARD ═══
# v2.3.5: ARCHITECTURAL PURITY FIX. The MOTD script is now delivered via the
# system_files overlay to /usr/libexec/cloudws/motd. We no longer perform
# manual 'install' calls here.
echo "[39-desktop-polish] MOTD dashboard delivered via overlay."

# ═══ FASTFETCH CONFIG — services dashboard on terminal open ═══
echo "[39-desktop-polish] Fastfetch config delivered via overlay."

# ═══ PROFILE.D — fastfetch + MOTD on terminal/TTY open ═══
echo "[39-desktop-polish] Profile.d MOTD script delivered via overlay."

echo "[39-desktop-polish] Desktop polish complete."
