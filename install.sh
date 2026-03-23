#!/bin/bash
# CloudWS — One-line installer for Linux
# Usage: curl -fsSL https://raw.githubusercontent.com/Kabuki94/CloudWS-bootc/main/install.sh | bash
set -euo pipefail

REPO="https://github.com/Kabuki94/CloudWS-bootc.git"
GHCR="ghcr.io/kabuki94/cloudws-bootc:latest"
DIR="${CLOUDWS_DIR:-$HOME/CloudWS-bootc}"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  CloudWS — Cloud Workstation OS Installer                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Detect environment
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "  OS: $PRETTY_NAME"
fi
echo "  Target: $DIR"
echo ""

echo "1) Pull pre-built image from GHCR (fastest)"
echo "2) Clone repo + build locally"
echo "3) Clone repo only (inspect first)"
echo "4) Install to bare metal from GHCR (bootc install)"
read -p "Choice [1-4]: " choice

case "$choice" in
  1)
    echo ""
    echo "Pulling $GHCR ..."
    if command -v podman &>/dev/null; then
        podman pull "$GHCR"
        echo ""
        echo "✓ Image pulled. Deploy with:"
        echo "  sudo podman run --rm -it --privileged --pid=host $GHCR bootc install to-disk /dev/sdX"
        echo "  # Replace /dev/sdX with your target disk"
    elif command -v docker &>/dev/null; then
        docker pull "$GHCR"
        echo ""
        echo "✓ Image pulled. Deploy with:"
        echo "  sudo docker run --rm -it --privileged --pid=host $GHCR bootc install to-disk /dev/sdX"
    else
        echo "✗ Neither podman nor docker found. Install one first."
        exit 1
    fi
    ;;
  2)
    echo ""
    echo "Cloning $REPO ..."
    git clone "$REPO" "$DIR" 2>/dev/null || { cd "$DIR" && git pull; }
    cd "$DIR"
    echo ""
    echo "Building OCI image..."
    if command -v podman &>/dev/null; then
        podman build --no-cache -t localhost/cloudws:latest -f Containerfile .
        echo ""
        echo "✓ Image built: localhost/cloudws:latest"
        echo "  Deploy: sudo podman run --rm -it --privileged --pid=host localhost/cloudws:latest bootc install to-disk /dev/sdX"
    elif command -v docker &>/dev/null; then
        docker build --no-cache -t localhost/cloudws:latest -f Containerfile .
        echo ""
        echo "✓ Image built: localhost/cloudws:latest"
    else
        echo "✗ Neither podman nor docker found."
        exit 1
    fi
    ;;
  3)
    echo ""
    echo "Cloning $REPO ..."
    git clone "$REPO" "$DIR" 2>/dev/null || { cd "$DIR" && git pull; }
    echo ""
    echo "✓ Repository cloned to $DIR"
    echo ""
    echo "  Inspect:  cd $DIR && ls -la"
    echo "  Build:    podman build --no-cache -t cloudws:latest ."
    echo "  Deploy:   sudo bootc switch ghcr.io/kabuki94/cloudws-bootc:latest"
    echo ""
    echo "  Windows:  Open PowerShell as Admin → .\\cloud-ws.ps1"
    ;;
  4)
    echo ""
    echo "Installing CloudWS directly to bare metal..."
    if [ "$(id -u)" -ne 0 ]; then
        echo "✗ Must run as root: sudo bash -c '\$(curl -fsSL https://raw.githubusercontent.com/Kabuki94/CloudWS-bootc/main/install.sh)'"
        exit 1
    fi
    echo ""
    echo "Available disks:"
    lsblk -d -o NAME,SIZE,MODEL,TRAN | grep -v "^NAME"
    echo ""
    read -p "Target disk (e.g., sda, nvme0n1): " disk
    read -p "⚠ ALL DATA ON /dev/$disk WILL BE DESTROYED. Continue? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        if command -v podman &>/dev/null; then
            podman run --rm -it --privileged --pid=host \
                -v /var/lib/containers:/var/lib/containers \
                -v /dev:/dev \
                "$GHCR" bootc install to-disk "/dev/$disk"
        elif command -v docker &>/dev/null; then
            docker run --rm -it --privileged --pid=host \
                -v /dev:/dev \
                "$GHCR" bootc install to-disk "/dev/$disk"
        fi
        echo ""
        echo "✓ CloudWS installed to /dev/$disk"
        echo "  Reboot to start CloudWS."
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
echo "CloudWS Links:"
echo "  Repo:    https://github.com/Kabuki94/CloudWS-bootc"
echo "  GHCR:    ghcr.io/kabuki94/cloudws-bootc:latest"
echo "  Update:  sudo bootc update"
echo "  Rebuild: cloudws-rebuild"
