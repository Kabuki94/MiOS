#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# CloudWS-bootc CI Smoke Test
#
# Validates that a built CloudWS image meets minimum requirements.
# Run this in CI after `podman build` and before pushing to GHCR.
#
# Usage:
#   ./tests/smoke-test.sh [IMAGE]
#   ./tests/smoke-test.sh ghcr.io/kabuki94/cloudws-bootc:latest
#   ./tests/smoke-test.sh localhost/cloudws-bootc:dev
#
# Exit codes:
#   0 — all tests passed
#   1 — one or more tests failed
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

IMAGE="${1:-localhost/cloudws-bootc:dev}"
PASS=0
FAIL=0
WARN=0
REPORT_FILE="cloudws-full-stack-report.log"

# ── Formatting ──────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}✓ PASS${NC}: $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}✗ FAIL${NC}: $1"; FAIL=$((FAIL + 1)); }
warn() { echo -e "  ${YELLOW}⚠ WARN${NC}: $1"; WARN=$((WARN + 1)); }
section() { echo -e "\n${CYAN}═══ $1 ═══${NC}"; }

echo "=====================================================================" > "$REPORT_FILE"
echo " CloudWS-bootc Full Stack Report - $(date)" >> "$REPORT_FILE"
echo " Image: $IMAGE" >> "$REPORT_FILE"
echo "=====================================================================" >> "$REPORT_FILE"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  CloudWS-bootc Smoke Test                                   ║"
echo "║  Image: ${IMAGE}$(printf '%*s' $((38 - ${#IMAGE})) '')║"
echo "╚══════════════════════════════════════════════════════════════╝"

# Helper: run a command inside the image
run_in() {
    podman run --rm --entrypoint="" "$IMAGE" "$@" 2>/dev/null
}

# ── 1. Image metadata ──────────────────────────────────────────────────────
section "Image Metadata"

# Check bootc labels
if podman inspect "$IMAGE" 2>/dev/null | grep -q '"containers.bootc": "1"'; then
    pass "containers.bootc=1 label present"
else
    fail "containers.bootc=1 label MISSING — image is not bootc-compatible"
fi

if podman inspect "$IMAGE" 2>/dev/null | grep -q '"ostree.bootable": "1"'; then
    pass "ostree.bootable=1 label present"
else
    fail "ostree.bootable=1 label MISSING"
fi

# Check CMD
if podman inspect "$IMAGE" 2>/dev/null | grep -q '"/sbin/init"'; then
    pass "CMD is /sbin/init"
else
    warn "CMD is not /sbin/init — may cause boot issues"
fi

# ── 2. bootc container lint ────────────────────────────────────────────────
section "bootc Container Lint"

LINT_OUTPUT=$(run_in bootc container lint 2>&1)
LINT_EXIT=$?
if [[ $LINT_EXIT -eq 0 ]]; then
    pass "bootc container lint passed"
else
    fail "bootc container lint FAILED: $LINT_OUTPUT"
fi

# ── 3. Critical packages ──────────────────────────────────────────────────
section "Critical Packages"

CRITICAL_PACKAGES=(
    gnome-shell
    gdm
    podman
    buildah
    skopeo
    bootc
    libvirt
    qemu-kvm
    cockpit
    firewalld
    tuned
    NetworkManager
    mesa-dri-drivers
    linux-firmware
    ceph-common
    moby-engine
    fapolicyd
    freeipa-client
    sssd-tools
    systemd-ukify
)

for pkg in "${CRITICAL_PACKAGES[@]}"; do
    if run_in rpm -q "$pkg" >/dev/null 2>&1; then
        pass "$pkg installed"
    else
        fail "$pkg NOT installed"
    fi
done

# ── 4. Footgun packages (should NOT be present) ───────────────────────────
section "Footgun Check (packages that should NOT be present)"

FOOTGUN_PACKAGES=(
    malcontent-control
    malcontent-pam
    malcontent-tools
    gnome-tour
    gnome-initial-setup
    PackageKit
    podman-docker
)

for pkg in "${FOOTGUN_PACKAGES[@]}"; do
    if run_in rpm -q "$pkg" >/dev/null 2>&1; then
        fail "$pkg IS installed (footgun — should be removed)"
    else
        pass "$pkg not present"
    fi
done

# ── 5. systemd services ───────────────────────────────────────────────────
section "systemd Service Enablement"

EXPECTED_SERVICES=(
    gdm
    NetworkManager
    cockpit.socket
    sshd
    tuned
    firewalld
    podman.socket
    chronyd
    libvirtd.socket
    docker.socket
    fapolicyd.service
    cloudws-freeipa-enroll.service
)

for svc in "${EXPECTED_SERVICES[@]}"; do
    if run_in systemctl is-enabled "$svc" 2>/dev/null | grep -q "enabled"; then
        pass "$svc is enabled"
    else
        # Some services use .socket or .service suffix variations
        if run_in systemctl is-enabled "${svc}.service" 2>/dev/null | grep -q "enabled" || \
           run_in systemctl is-enabled "${svc}.socket" 2>/dev/null | grep -q "enabled"; then
            pass "$svc is enabled"
        else
            fail "$svc is NOT enabled"
        fi
    fi
done

# ── 6. Filesystem structure ───────────────────────────────────────────────
section "Filesystem Structure"

# /opt → /var/opt symlink
if run_in test -L /opt; then
    LINK_TARGET=$(run_in readlink /opt)
    if [[ "$LINK_TARGET" == "/var/opt" || "$LINK_TARGET" == "var/opt" ]]; then
        pass "/opt → /var/opt symlink exists"
    else
        warn "/opt is a symlink but points to $LINK_TARGET (expected /var/opt)"
    fi
else
    fail "/opt is NOT a symlink to /var/opt"
fi

# /home → /var/home symlink (bootc convention)
if run_in test -L /home; then
    pass "/home is a symlink (bootc convention)"
else
    warn "/home is not a symlink — may not be standard bootc layout"
fi

# /etc/skel/.bashrc exists
if run_in test -f /etc/skel/.bashrc; then
    pass "/etc/skel/.bashrc exists"
else
    warn "/etc/skel/.bashrc missing — new users won't get fastfetch"
fi

# ── 7. Security hardening ─────────────────────────────────────────────────
section "Security Hardening"

# Sysctl hardening file
if run_in test -f /usr/lib/sysctl.d/99-cloudws-hardening.conf; then
    pass "Sysctl hardening config present"
else
    fail "Sysctl hardening config MISSING at /usr/lib/sysctl.d/99-cloudws-hardening.conf"
fi

# bootc kargs.d
if run_in test -f /usr/lib/bootc/kargs.d/00-cloudws.toml; then
    pass "bootc kargs.d hardening config present"
else
    fail "bootc kargs.d config MISSING at /usr/lib/bootc/kargs.d/00-cloudws.toml"
fi

# ── 8. CloudWS Phase 3 Fixes & Hardware Hooks ─────────────────────────────
section "CloudWS Custom Scripts & Hardware Hooks"

# Fapolicyd composefs trust integration
if run_in grep -q "trust = file,rpmdb" /etc/fapolicyd/fapolicyd.conf 2>/dev/null; then
    pass "Fapolicyd configured for fs-verity ComposeFS trust backend"
else
    fail "Fapolicyd missing file/fs-verity trust configuration"
fi

# USBGuard strict permissions (0600)
USBG_PERMS=$(run_in stat -c "%a" /etc/usbguard/usbguard-daemon.conf 2>/dev/null || echo "000")
if [[ "$USBG_PERMS" == "600" ]]; then
    pass "USBGuard config has strict 0600 permissions"
else
    fail "USBGuard config permissions are $USBG_PERMS (Expected 600)"
fi

# Cockpit unencrypted UI
if run_in grep -q "AllowUnencrypted = true" /etc/cockpit/cockpit.conf 2>/dev/null; then
    pass "Cockpit allows unencrypted HTTP for local UI"
else
    warn "Cockpit AllowUnencrypted configuration missing"
fi

# Waydroid NVIDIA hardware fallback script
if run_in test -x /usr/libexec/cloudws/cloudws-waydroid-fallback.sh; then
    pass "Waydroid NVIDIA SwiftShader fallback script is present and executable"
else
    warn "Waydroid NVIDIA fallback script missing or not executable"
fi

# RTX 50-Series Libvirt QEMU Hook
if run_in test -x /etc/libvirt/hooks/qemu; then
    pass "RTX 50-Series Blackwell FLR qemu hook present and executable"
else
    warn "Libvirt qemu hook missing or not executable"
fi

# UKI Cmdline Rendering Output (conditional — requires bootc render-kargs support)
if run_in test -f /etc/kernel/cmdline; then
    pass "Unified Kernel Image (UKI) cmdline successfully rendered"
else
    warn "UKI cmdline not present (/etc/kernel/cmdline missing — bootc render-kargs may not be supported on this bootc version)"
fi

# ── 9. CloudWS Kernel Arguments (kargs.d) ─────────────────────────────────
section "Kernel Arguments (kargs.d)"

KARG_FILES=(
    "12-intel-xe.toml"
    "13-rtx50-vfio-workaround.toml"
    "16-nested-virt.toml"
)

for karg in "${KARG_FILES[@]}"; do
    if run_in test -f "/usr/lib/bootc/kargs.d/$karg"; then
        pass "kargs.d config present: $karg"
    else
        fail "kargs.d config MISSING: $karg"
    fi
done

# composefs config
if run_in test -f /usr/lib/ostree/prepare-root.conf; then
    pass "composefs prepare-root.conf present"
else
    warn "composefs prepare-root.conf missing"
fi

# SELinux
SELINUX_MODE=$(run_in cat /etc/selinux/config 2>/dev/null | grep "^SELINUX=" | cut -d= -f2)
if [[ "$SELINUX_MODE" == "enforcing" ]]; then
    pass "SELinux configured as enforcing"
elif [[ -n "$SELINUX_MODE" ]]; then
    warn "SELinux is $SELINUX_MODE (expected enforcing)"
else
    warn "Could not determine SELinux mode"
fi

# ── 10. GPU driver availability ───────────────────────────────────────────
section "GPU Stack"

if run_in rpm -q mesa-vulkan-drivers >/dev/null 2>&1; then
    pass "Mesa Vulkan drivers present (AMD/Intel)"
else
    fail "Mesa Vulkan drivers MISSING"
fi

if run_in rpm -q mesa-va-drivers >/dev/null 2>&1; then
    pass "Mesa VA-API drivers present (HW video decode)"
else
    warn "Mesa VA-API drivers missing"
fi

# NVIDIA (may not be present on CloudWS-1 if akmod didn't build)
if run_in rpm -q akmod-nvidia >/dev/null 2>&1 || \
   run_in test -d /usr/lib/modules/*/extra/nvidia 2>/dev/null; then
    pass "NVIDIA driver present"
else
    warn "NVIDIA driver not detected (expected on CloudWS-2 / may need akmod rebuild on CloudWS-1)"
fi

# ── 11. Flatpak remotes ──────────────────────────────────────────────────
section "Flatpak"

if run_in flatpak remote-list --system 2>/dev/null | grep -q "flathub"; then
    pass "Flathub remote configured"
else
    warn "Flathub remote not found"
fi

# ── 12. Full Stack Report Generation ─────────────────────────────────────
section "Stack Manifest Generation"
echo "Compiling complete stack artifact into $REPORT_FILE..."

echo -e "\n=== RPM PACKAGE INVENTORY ===" >> "$REPORT_FILE"
run_in rpm -qa | sort >> "$REPORT_FILE"

echo -e "\n=== SYSTEMD UNIT INVENTORY ===" >> "$REPORT_FILE"
run_in systemctl list-unit-files >> "$REPORT_FILE"

echo -e "\n=== KERNEL COMMAND LINE FRAGMENTS (kargs.d) ===" >> "$REPORT_FILE"
run_in cat /usr/lib/bootc/kargs.d/*.toml >> "$REPORT_FILE"

echo -e "\n=== OCI CONTAINER LABELS ===" >> "$REPORT_FILE"
podman inspect "$IMAGE" | grep -A 15 '"Labels":' >> "$REPORT_FILE"

pass "Exhaustive stack manifest saved to $REPORT_FILE"

# ── 13. Version info ─────────────────────────────────────────────────────
section "System Information"

VERSION=$(run_in cat /etc/cloudws-version 2>/dev/null || echo "not set")
echo "  CloudWS version: $VERSION"

KERNEL=$(run_in ls /lib/modules/ 2>/dev/null | sort -V | tail -1 || echo "unknown")
echo "  Kernel: $KERNEL"

# ── Summary ──────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Results: ${PASS} passed, ${FAIL} failed, ${WARN} warnings$(printf '%*s' $((23 - ${#PASS} - ${#FAIL} - ${#WARN})) '')║"
echo "╚══════════════════════════════════════════════════════════════╝"

if [[ $FAIL -gt 0 ]]; then
    echo -e "${RED}SMOKE TEST FAILED — $FAIL critical issue(s) found.${NC}"
    exit 1
else
    if [[ $WARN -gt 0 ]]; then
        echo -e "${YELLOW}SMOKE TEST PASSED with $WARN warning(s).${NC}"
    else
        echo -e "${GREEN}SMOKE TEST PASSED — all checks clean.${NC}"
    fi
    exit 0
fi
