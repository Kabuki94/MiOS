#!/bin/bash
# CloudWS v2.0 — 34-gpu-detect: GPU environment detection service
# Blocks NVIDIA modules in VMs, enables hardware renderer on bare metal,
# detects RTX 50-series VFIO reset bug.
set -euo pipefail

echo "[34-gpu-detect] Installing GPU auto-detect service..."

cat > /usr/lib/systemd/system/cloudws-gpu-detect.service <<'EOGPUSVC'
[Unit]
Description=CloudWS GPU Environment Detection
DefaultDependencies=no
Before=gdm.service display-manager.service systemd-modules-load.service
After=local-fs.target systemd-udevd.service
ConditionPathExists=!/run/cloudws-gpu-detected
[Service]
Type=oneshot
ExecStart=/usr/libexec/cloudws-gpu-detect
RemainAfterExit=yes
[Install]
WantedBy=sysinit.target
EOGPUSVC

cat > /usr/libexec/cloudws-gpu-detect <<'EOGPU'
#!/bin/bash
set -euo pipefail
VIRT=$(systemd-detect-virt 2>/dev/null || echo "none")
echo "[cloudws-gpu-detect] Virtualization: $VIRT"

NVIDIA_CONF="/etc/modprobe.d/99-cloudws-virt-gpu.conf"
ENV_DIR="/etc/environment.d"
RENDERER_CONF="${ENV_DIR}/60-cloudws-renderer.conf"
mkdir -p "$ENV_DIR"

if [ "$VIRT" != "none" ]; then
    echo "[cloudws-gpu-detect] VM detected ($VIRT) — blocking NVIDIA"
    cat > "$NVIDIA_CONF" <<'EOMOD'
install nvidia /bin/false
install nvidia_drm /bin/false
install nvidia_modeset /bin/false
install nvidia_uvm /bin/false
EOMOD
    for mod in nvidia_uvm nvidia_drm nvidia_modeset nvidia; do
        modprobe -r "$mod" 2>/dev/null || true
    done

    cat > "$RENDERER_CONF" <<'EORENDER'
GSK_RENDERER=cairo
GDK_DISABLE=vulkan
EORENDER

    case "$VIRT" in
        microsoft|wsl) modprobe hyperv_drm 2>/dev/null || true ;;
        kvm|qemu)      modprobe virtio-gpu 2>/dev/null || true ;;
        vmware)        modprobe vmwgfx 2>/dev/null || true ;;
    esac
else
    echo "[cloudws-gpu-detect] Bare metal — NVIDIA enabled, hardware renderer"
    rm -f "$NVIDIA_CONF"
    rm -f /etc/modprobe.d/cloudws-nvidia-blacklist.conf
    # Load nvidia now that blacklist is removed
    modprobe nvidia_drm 2>/dev/null || true
    rm -f "$RENDERER_CONF"

    # RTX 50-series (Blackwell) VFIO reset bug detection
    if command -v lspci &>/dev/null; then
        if lspci -nn | grep -iE '\[10de:(2900|2901|2903|2904|2905|2b80|2b85)\]' &>/dev/null; then
            echo "[cloudws-gpu-detect] WARNING: RTX 50-series GPU detected!"
            echo "[cloudws-gpu-detect] VFIO passthrough may require full host reboot after VM shutdown."
            wall "CloudWS: RTX 50-series VFIO reset bug detected." 2>/dev/null || true
        fi
    fi
fi

touch /run/cloudws-gpu-detected
EOGPU
chmod +x /usr/libexec/cloudws-gpu-detect
systemctl enable cloudws-gpu-detect.service 2>/dev/null || true

echo "[34-gpu-detect] GPU detection service installed."
