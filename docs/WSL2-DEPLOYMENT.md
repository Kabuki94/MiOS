# CloudWS-bootc — WSL2 Deployment Guide

## Overview
Because WSL2 manages its own Linux kernel, you cannot "boot" a standard `bootc` image directly in WSL2 using its internal kernel and bootloader. However, you can use the **CloudWS-bootc userland** (all your packages, configs, and tools) as a WSL2 distribution.

## Method 1: Rootfs Export (Recommended)
This method exports the container's filesystem and imports it as a standard WSL distribution.

### 1. Build or Pull the Image
```bash
podman pull ghcr.io/kabuki94/cloudws-bootc:latest
```

### 2. Export the Rootfs
```bash
podman export $(podman create ghcr.io/kabuki94/cloudws-bootc:latest) -o cloudws-bootc.tar
```

### 3. Import into WSL (PowerShell)
```powershell
wsl --import CloudWS-bootc $env:USERPROFILE\WSL\CloudWS-bootc .\cloudws-bootc.tar
```

### 4. Automatic Configuration (v1.3.0+)
Starting with **v1.3.0**, CloudWS-bootc automatically configures itself for WSL2 during the build:
*   **systemd is enabled by default** via a static symlink at `/etc/wsl.conf`.
*   **Default user is set to `cloudws`** automatically.
*   **Graphical Support (WSLg)** works out-of-the-box with no manual DISPLAY configuration required.
*   **Home Directories** are correctly provisioned in `/var/home` with a `/home` symlink for compatibility.

No manual updates to `/etc/wsl.conf` are required after import.

---

## Method 2: VM-based Testing (podman-bootc)
If you need to test the actual `bootc` kernel and boot process, you must use nested virtualization.

### 1. Enable Nested Virtualization
In Windows PowerShell (Admin):
```powershell
Set-VMProcessor -VMName "WSL" -ExposeVirtualizationExtensions $true
```

In `.wslconfig` (typically `%UserProfile%\.wslconfig`):
```ini
[wsl2]
nestedVirtualization=true
```

### 2. Install Testing Tools
Inside your primary WSL distro (e.g., Ubuntu/Fedora):
```bash
sudo dnf install qemu-system-x86 libvirt-daemon-system virtiofsd
sudo systemctl enable --now libvirtd
```

### 3. Run with podman-bootc
```bash
podman-bootc run --image ghcr.io/kabuki94/cloudws-bootc:latest
```

---

## Known Limitations in WSL2
- **NVIDIA GPU:** WSL2 uses its own `libdxcore` and `/dev/dxg` for GPU acceleration. The NVIDIA drivers in the `bootc` image (kernel modules) will not load. You must use the host's Windows drivers mapped into WSL2.
- **Firewalld/SELinux:** These are often limited or disabled in WSL2 environments to ensure interop stability.
