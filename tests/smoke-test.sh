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

# ── 8. GPU driver availability ────────────────────────────────────────────
section "GPU Drivers"

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

# ── 9. Flatpak remotes ───────────────────────────────────────────────────
section "Flatpak"

if run_in flatpak remote-list --system 2>/dev/null | grep -q "flathub"; then
    pass "Flathub remote configured"
else
    warn "Flathub remote not found"
fi

# ── 10. Version info ─────────────────────────────────────────────────────
section "Version Info"

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
