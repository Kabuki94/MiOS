#!/bin/bash
# CloudWS — One-line installer for Linux
# Usage: curl -fsSL https://raw.githubusercontent.com/Kabuki94/CloudWS-bootc/main/install.sh | bash
set -euo pipefail

REPO="https://github.com/Kabuki94/CloudWS-bootc.git"
DIR="${CLOUDWS_DIR:-$HOME/CloudWS-bootc}"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  CloudWS v3.12 — Cloud Workstation OS                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

if [ -f /etc/os-release ]; then . /etc/os-release; echo "  OS: $PRETTY_NAME"; fi
echo "  Target: $DIR"
echo ""

echo "1) Clone repo + build OCI image locally"
echo "2) Clone repo only (inspect first)"
echo "3) Install to bare metal (requires root + target disk)"
read -p "Choice [1-3]: " choice

case "$choice" in
  1)
    echo ""
    echo "Cloning $REPO ..."
    git clone "$REPO" "$DIR" 2>/dev/null || { cd "$DIR" && git pull; }
    cd "$DIR"
    echo ""
    echo "Building OCI image..."
    if command -v podman &>/dev/null; then
        podman build --no-cache --squash-all -t localhost/cloudws:latest .
        echo ""
        echo "✓ Image built: localhost/cloudws:latest"
        echo ""
        echo "Deploy options:"
        echo "  Bare metal:  sudo podman run --rm -it --privileged --pid=host localhost/cloudws:latest bootc install to-disk /dev/sdX"
        echo "  Switch live: sudo bootc switch --transport containers-storage localhost/cloudws:latest"
    elif command -v docker &>/dev/null; then
        docker build --no-cache -t localhost/cloudws:latest .
        echo "✓ Image built: localhost/cloudws:latest"
    else
        echo "✗ Neither podman nor docker found."
        exit 1
    fi
    ;;
  2)
    echo ""
    echo "Cloning $REPO ..."
    git clone "$REPO" "$DIR" 2>/dev/null || { cd "$DIR" && git pull; }
    echo ""
    echo "✓ Repository cloned to $DIR"
    echo ""
    echo "  Inspect:   cd $DIR && ls -la"
    echo "  Build:     podman build --no-cache --squash-all -t cloudws:latest ."
    echo "  Windows:   Open PowerShell as Admin → .\\cloud-ws.ps1"
    ;;
  3)
    echo ""
    if [ "$(id -u)" -ne 0 ]; then
        echo "✗ Must run as root."
        echo "  sudo bash -c '\$(curl -fsSL https://raw.githubusercontent.com/Kabuki94/CloudWS-bootc/main/install.sh)'"
        exit 1
    fi
    echo "Available disks:"
    lsblk -d -o NAME,SIZE,MODEL,TRAN | grep -v "^NAME"
    echo ""
    read -p "Target disk (e.g., sda, nvme0n1): " disk
    read -p "Enable LUKS encryption? (y/n): " use_luks
    luks_flag=""
    if [ "$use_luks" = "y" ]; then
        while true; do
            read -sp "LUKS passphrase: " lp1; echo
            read -sp "Confirm passphrase: " lp2; echo
            if [ "$lp1" = "$lp2" ]; then luks_flag="--luks-passphrase $lp1"; break
            else echo "Passphrases do not match. Try again."; fi
        done
    fi
    read -p "⚠ ALL DATA ON /dev/$disk WILL BE DESTROYED. Type 'yes' to continue: " confirm
    if [ "$confirm" = "yes" ]; then
        echo "Building image..."
        git clone "$REPO" /tmp/cloudws-build 2>/dev/null || true
        cd /tmp/cloudws-build
        podman build --no-cache --squash-all -t localhost/cloudws:latest .
        echo "Installing to /dev/$disk ..."
        podman run --rm -it --privileged --pid=host \
            -v /var/lib/containers:/var/lib/containers \
            -v /dev:/dev \
            localhost/cloudws:latest bootc install to-disk $luks_flag "/dev/$disk"
        echo ""
        echo "✓ CloudWS installed to /dev/$disk. Reboot to start."
    else
        echo "Aborted."
    fi
    ;;
  *)
    echo "Invalid choice."
    exit 1
    ;;
esac

echo ""
echo "CloudWS Commands (after deploy):"
echo "  sudo bootc update     — Pull latest updates"
echo "  sudo bootc rollback   — Roll back"
echo "  cloudws-rebuild       — Clone from GitHub, build, push"
echo "  cloudws-backup        — Backup volumes, K3s state, VMs"
echo "  cloudws-vfio-toggle   — GPU passthrough management"
