#!/bin/bash
# CloudWS v2.1 — 98-boot-config: Console output + plymouth mask
# Ensures the boot process is VISIBLE on all deployment surfaces.
set -euo pipefail

echo "[98-boot-config] Configuring boot console output..."

# ── Mask plymouth ──────────────────────────────────────────────────────────
# Plymouth steals the framebuffer console. In Hyper-V, QEMU, and serial
# consoles this means ZERO visible output during boot. The system appears
# completely hung even though systemd is making progress.
#
# Masking creates /dev/null symlinks that prevent the service from starting.
echo "[98-boot-config] Masking plymouth services..."
systemctl mask plymouth-start.service 2>/dev/null || true
systemctl mask plymouth-quit.service 2>/dev/null || true
systemctl mask plymouth-quit-wait.service 2>/dev/null || true
systemctl mask plymouth-read-write.service 2>/dev/null || true
systemctl mask plymouth-reboot.service 2>/dev/null || true
systemctl mask plymouth-switch-root.service 2>/dev/null || true

# ── Ensure agetty on tty1 ─────────────────────────────────────────────────
# Even if GDM fails, we need a text console to diagnose.
echo "[98-boot-config] Enabling getty on tty1 (fallback console)..."
systemctl enable getty@tty1.service 2>/dev/null || true

# ── Emergency shell access ────────────────────────────────────────────────
# Allow root login on console for emergency debugging.
# This is overridden by proper user auth once the system is up.
echo "[98-boot-config] Enabling emergency/rescue shell access..."
systemctl enable emergency.service 2>/dev/null || true
systemctl enable rescue.service 2>/dev/null || true

# ── Serial console for Hyper-V / QEMU ────────────────────────────────────
echo "[98-boot-config] Enabling serial-getty on ttyS0..."
systemctl enable serial-getty@ttyS0.service 2>/dev/null || true

# ── Disable systemd services known to hang in VMs ─────────────────────────
# NetworkManager-wait-online blocks boot for 90s if no network is configured
echo "[98-boot-config] Setting NetworkManager-wait-online timeout..."
mkdir -p /etc/systemd/system/NetworkManager-wait-online.service.d
cat > /etc/systemd/system/NetworkManager-wait-online.service.d/timeout.conf <<'EOF'
[Service]
TimeoutStartSec=10
EOF

echo "[98-boot-config] ✓ Boot console configured"
echo "[98-boot-config]   plymouth: masked (verbose systemd output visible)"
echo "[98-boot-config]   getty@tty1: enabled (fallback text console)"
echo "[98-boot-config]   serial-getty@ttyS0: enabled (serial console)"
echo "[98-boot-config]   NM-wait-online: 10s timeout (was 90s)"
# Enable boot diagnostic service
echo "[98-boot-config] Enabling boot diagnostic service..."
systemctl enable cloudws-boot-diag.service 2>/dev/null || true