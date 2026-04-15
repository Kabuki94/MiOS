#!/bin/bash
# CloudWS v2.1.1 — 98-boot-config: Console output + boot diagnostics
# Ensures the boot process is VISIBLE on all deployment surfaces.
#
# v2.1.1 CRITICAL FIX: Plymouth is disabled via kernel command line, NOT by
# masking services. Masking plymouth-quit-wait.service creates a dependency
# deadlock when GDM or other display managers have ordering dependencies on it.
# This was a root cause of the Hyper-V boot hang — systemd would stall
# waiting for a masked dependency that could never complete its ordering chain.
set -euo pipefail

echo "[98-boot-config] Configuring boot console output..."

# ── Plymouth: disable via kernel cmdline (NOT masking) ───────────────────────
# plymouth.enable=0 tells plymouth to no-op without breaking systemd's
# dependency resolution. This is safer than masking because:
#   1. Units that After=plymouth-quit-wait.service still resolve correctly
#   2. No symlink-to-/dev/null that confuses systemd dependency graph
#   3. The kernel parameter is honored before systemd even starts
echo "[98-boot-config] Configuring plymouth disable via kernel cmdline..."
mkdir -p /usr/lib/bootc/kargs.d
cat > /usr/lib/bootc/kargs.d/10-cloudws-console.toml <<'EOF'
# CloudWS: Visible boot output on all surfaces (Hyper-V, QEMU, bare metal)
# plymouth.enable=0: disables plymouth splash without breaking systemd deps
# console=tty0: ensures kernel messages go to primary virtual console
# console=ttyS0,115200n8: serial console for headless/remote diagnosis
[kargs]
match-architectures = ["x86_64"]
kargs = ["plymouth.enable=0", "console=tty0", "console=ttyS0,115200n8"]
EOF

# ── Ensure agetty on tty1 ─────────────────────────────────────────────────
# Even if GDM fails, we need a text console to diagnose.
echo "[98-boot-config] Enabling getty on tty1 (fallback console)..."
systemctl enable getty@tty1.service 2>/dev/null || true

# ── Emergency shell access ────────────────────────────────────────────────
echo "[98-boot-config] Enabling emergency/rescue shell access..."
systemctl enable emergency.service 2>/dev/null || true
systemctl enable rescue.service 2>/dev/null || true

# ── Serial console for Hyper-V / QEMU ────────────────────────────────────
echo "[98-boot-config] Enabling serial-getty on ttyS0..."
systemctl enable serial-getty@ttyS0.service 2>/dev/null || true

# ── NetworkManager-wait-online timeout ────────────────────────────────────
echo "[98-boot-config] Setting NetworkManager-wait-online timeout..."
mkdir -p /etc/systemd/system/NetworkManager-wait-online.service.d
cat > /etc/systemd/system/NetworkManager-wait-online.service.d/timeout.conf <<'EOF'
[Service]
TimeoutStartSec=10
EOF

# ── NOTE: cloudws-boot-diag.service is enabled in Containerfile STEP D ────
# The unit file lives in system_files/ and isn't available at script time.

echo "[98-boot-config] ✓ Boot console configured"
echo "[98-boot-config]   plymouth: disabled (kernel cmdline plymouth.enable=0)"
echo "[98-boot-config]   getty@tty1: enabled (fallback text console)"
echo "[98-boot-config]   serial-getty@ttyS0: enabled (serial console)"
echo "[98-boot-config]   NM-wait-online: 10s timeout (was 90s)"
