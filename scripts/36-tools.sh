#!/bin/bash
# CloudWS v2.0 — 36-tools: CLI tools and consolidated cloudws command
# Installs all cloudws-* tools to /usr/bin/ and the master 'cloudws' CLI.
set -euo pipefail

echo "[36-tools] Installing CloudWS CLI tools..."

# ═══ MASTER CLI: cloudws [command] [--options] ═══
cat > /usr/bin/cloudws <<'EOTOOL'
#!/bin/bash
# CloudWS v2.0 — Unified management CLI
set -euo pipefail
VERSION="2.0.0"
CMD="${1:-help}"
shift 2>/dev/null || true

case "$CMD" in
    --help|-h|help)
        echo ""
        echo "  CloudWS v${VERSION} — Cloud Workstation OS"
        echo "  ══════════════════════════════════════════"
        echo ""
        echo "  USAGE: cloudws <command> [options]"
        echo ""
        echo "  SYSTEM"
        echo "    update          Check for & apply OS updates (bootc)"
        echo "    rebuild         Clone repo, build from source, push to GHCR"
        echo "    build           Local OCI build only (no push)"
        echo "    deploy <image>  Switch to a different CloudWS image"
        echo "    backup          Snapshot /etc + /var/home"
        echo "    status          Show system & service status"
        echo ""
        echo "  DESKTOP"
        echo "    toggle-headless Switch between desktop and headless mode"
        echo "    test            Run system health checks"
        echo ""
        echo "  VIRTUALIZATION"
        echo "    vfio-toggle     Bind/unbind GPU from vfio-pci"
        echo "    vfio-check      Validate VFIO passthrough readiness"
        echo "    iommu-groups    List IOMMU groups"
        echo ""
        echo "  CONTAINERS"
        echo "    gc              Run Podman garbage collection now"
        echo "    gc-status       Show Podman disk usage"
        echo ""
        echo "  SECURITY"
        echo "    scan-malware    ClamAV container scan of /home"
        echo ""
        echo "  INFO"
        echo "    version         Show CloudWS version"
        echo "    motd            Show management dashboard"
        echo "    help            Show this help"
        echo ""
        ;;
    version|--version|-v)
        echo "CloudWS v${VERSION}"
        ;;
    update)      exec /usr/bin/cloudws-update "$@" ;;
    rebuild)     exec /usr/bin/cloudws-rebuild "$@" ;;
    build)       exec /usr/bin/cloudws-build "$@" ;;
    deploy)      exec /usr/bin/cloudws-deploy "$@" ;;
    backup)      exec /usr/bin/cloudws-backup "$@" ;;
    status)      exec /usr/bin/cloudws-status "$@" ;;
    toggle-headless) exec /usr/bin/cloudws-toggle-headless "$@" ;;
    test)        exec /usr/bin/cloudws-test "$@" ;;
    vfio-toggle) exec /usr/bin/cloudws-vfio-toggle "$@" ;;
    vfio-check)  exec /usr/bin/cloudws-vfio-check "$@" ;;
    iommu-groups|iommu) exec /usr/bin/iommu-groups "$@" ;;
    gc)          exec /usr/libexec/cloudws-podman-gc "$@" ;;
    gc-status)   podman system df 2>/dev/null || echo "Podman not available" ;;
    scan-malware|scan)
        podman run --rm -v /:/scan:ro docker.io/clamav/clamav:latest \
            clamscan -r /scan/home --max-filesize=100M --max-scansize=500M 2>/dev/null
        ;;
    motd)        exec /usr/libexec/cloudws-motd ;;
    *)
        echo "Unknown command: $CMD"
        echo "Run 'cloudws --help' for available commands."
        exit 1
        ;;
esac
EOTOOL

# ═══ cloudws-update ═══
cat > /usr/bin/cloudws-update <<'EOTOOL'
#!/bin/bash
set -euo pipefail
echo "CloudWS v2.0 — Checking for updates..."
ORIGIN=$(bootc status 2>/dev/null | grep -i "image:" | head -1 | awk '{print $NF}' || echo "")
if echo "$ORIGIN" | grep -q "localhost"; then
    echo "WARNING: Update origin is localhost — switching to GHCR..."
    sudo bootc switch ghcr.io/kabuki94/cloudws-bootc:latest
else
    echo "Current image: $ORIGIN"
    sudo bootc upgrade
    echo ""
    echo "If an update was staged, reboot to apply: sudo reboot"
fi
EOTOOL

# ═══ cloudws-rebuild (FIXED: no --squash-all) ═══
cat > /usr/bin/cloudws-rebuild <<'EOTOOL'
#!/bin/bash
set -euo pipefail
DIR="${CLOUDWS_DIR:-$HOME/CloudWS-bootc}"
echo "CloudWS — Rebuilding from source..."
if [ ! -d "$DIR" ]; then
    git clone https://github.com/Kabuki94/CloudWS-bootc.git "$DIR"
else
    cd "$DIR" && git pull
fi
cd "$DIR"
if command -v just &>/dev/null; then
    just all
else
    podman build --no-cache --build-arg MAKEFLAGS="-j$(nproc)" -t localhost/cloudws:latest .
    podman push localhost/cloudws:latest ghcr.io/kabuki94/cloudws-bootc:latest
fi
EOTOOL

# ═══ cloudws-build (FIXED: no --squash-all) ═══
cat > /usr/bin/cloudws-build <<'EOTOOL'
#!/bin/bash
set -euo pipefail
echo "CloudWS — Local build..."
podman build --no-cache --build-arg MAKEFLAGS="-j$(nproc)" -t localhost/cloudws:latest .
EOTOOL

# ═══ cloudws-backup ═══
cat > /usr/bin/cloudws-backup <<'EOTOOL'
#!/bin/bash
set -euo pipefail
BACKUP_DIR="/var/lib/cloudws/backups"
TS=$(date +%Y%m%d-%H%M%S)
mkdir -p "$BACKUP_DIR"
echo "CloudWS — Backing up system state..."
tar czf "$BACKUP_DIR/etc-${TS}.tar.gz" /etc/ 2>/dev/null || true
tar czf "$BACKUP_DIR/home-${TS}.tar.gz" /var/home/ 2>/dev/null || true
echo "Backups saved to $BACKUP_DIR/"
ls -lh "$BACKUP_DIR/"*"${TS}"*
EOTOOL

# ═══ cloudws-deploy ═══
cat > /usr/bin/cloudws-deploy <<'EOTOOL'
#!/bin/bash
set -euo pipefail
IMAGE="${1:-ghcr.io/kabuki94/cloudws-bootc:latest}"
echo "CloudWS — Deploying $IMAGE to bare metal..."
echo "WARNING: This will overwrite the current system!"
read -rp "Continue? [y/N]: " confirm
if [[ "$confirm" =~ ^[Yy] ]]; then
    sudo bootc switch "$IMAGE"
    echo "Deploy staged. Reboot to apply: sudo reboot"
fi
EOTOOL

# ═══ cloudws-status ═══
cat > /usr/bin/cloudws-status <<'EOTOOL'
#!/bin/bash
echo "CloudWS v2.0 — System Status"
echo "════════════════════════════════"
echo ""
echo "Hostname:  $(hostname)"
echo "Uptime:    $(uptime -p 2>/dev/null || uptime)"
echo "Kernel:    $(uname -r)"
echo "bootc:     $(bootc status 2>/dev/null | head -3 || echo 'N/A')"
echo ""
echo "Services:"
for svc in gdm cockpit.socket sshd libvirtd.socket podman.socket \
           firewalld tuned k3s gnome-remote-desktop xrdp avahi-daemon; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        printf "  ✓ %-30s active\n" "$svc"
    elif systemctl is-enabled --quiet "$svc" 2>/dev/null; then
        printf "  ○ %-30s enabled (inactive)\n" "$svc"
    fi
done
echo ""
echo "Podman:"
podman system df 2>/dev/null || echo "  Not available"
EOTOOL

# ═══ cloudws-vfio-toggle ═══
cat > /usr/bin/cloudws-vfio-toggle <<'EOTOOL'
#!/bin/bash
set -euo pipefail
if [ -z "${1:-}" ]; then
    echo "Usage: cloudws vfio-toggle <PCI_SLOT> [bind|unbind]"
    echo "Example: cloudws vfio-toggle 0000:01:00.0 bind"
    exit 1
fi
PCI="$1"; ACTION="${2:-bind}"
if [ "$ACTION" = "bind" ]; then
    echo "$PCI" | sudo tee /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || true
    echo "Bound $PCI to vfio-pci"
else
    echo "$PCI" | sudo tee /sys/bus/pci/drivers/vfio-pci/unbind 2>/dev/null || true
    echo "Unbound $PCI from vfio-pci"
fi
EOTOOL

# ═══ cloudws-vfio-check ═══
cat > /usr/bin/cloudws-vfio-check <<'EOTOOL'
#!/bin/bash
set -euo pipefail
echo "CloudWS v2.0 — VFIO Passthrough Readiness Check"
echo "════════════════════════════════════════════════"
echo ""
if dmesg 2>/dev/null | grep -qi "IOMMU enabled"; then
    echo "  ✓ IOMMU: Enabled"
else
    echo "  ✗ IOMMU: Not detected (add iommu=pt to kernel args)"
fi
for mod in vfio vfio_iommu_type1 vfio_pci; do
    if modprobe -n "$mod" 2>/dev/null; then
        echo "  ✓ Module: $mod available"
    else
        echo "  ✗ Module: $mod not available"
    fi
done
echo ""
echo "NVIDIA GPUs detected:"
lspci -nn 2>/dev/null | grep -i nvidia | while read -r line; do
    echo "  $line"
    if echo "$line" | grep -qiE '\[10de:(2900|2901|2903|2904|2905|2b80|2b85)\]'; then
        echo "    ⚠ WARNING: RTX 50-series — VFIO reset bug!"
    fi
done
echo ""
echo "IOMMU Groups with NVIDIA:"
shopt -s nullglob
for g in /sys/kernel/iommu_groups/*; do
    for d in "$g"/devices/*; do
        if lspci -nns "${d##*/}" 2>/dev/null | grep -qi nvidia; then
            echo "  Group ${g##*/}: $(lspci -nns "${d##*/}")"
        fi
    done
done
EOTOOL

# ═══ iommu-groups ═══
cat > /usr/bin/iommu-groups <<'EOTOOL'
#!/bin/bash
shopt -s nullglob
for g in /sys/kernel/iommu_groups/*; do
    echo -e "\033[1;34mIOMMU Group ${g##*/}:\033[0m"
    for d in "$g"/devices/*; do
        echo "  $(lspci -nns "${d##*/}")"
    done
done
EOTOOL

# Make all tools executable
for tool in cloudws cloudws-update cloudws-rebuild cloudws-build cloudws-backup \
            cloudws-deploy cloudws-status cloudws-vfio-toggle cloudws-vfio-check \
            iommu-groups; do
    chmod +x "/usr/bin/$tool"
done

# ═══ Install external scripts from build context ═══
echo "[36-tools] Installing cloudws-toggle-headless and cloudws-test..."
if [ -f /tmp/build/scripts/cloudws-toggle-headless ]; then
    cp /tmp/build/scripts/cloudws-toggle-headless /usr/bin/cloudws-toggle-headless
    chmod +x /usr/bin/cloudws-toggle-headless
fi
if [ -f /tmp/build/scripts/cloudws-test ]; then
    cp /tmp/build/scripts/cloudws-test /usr/bin/cloudws-test
    chmod +x /usr/bin/cloudws-test
fi

echo "[36-tools] CLI tools installed. Run 'cloudws --help' for commands."
