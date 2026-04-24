# CloudWS-bootc — WSL2 Deployment Guide

## Overview
Because WSL2 manages its own Linux kernel, you cannot "boot" a standard `bootc` image directly in WSL2 using its internal kernel and bootloader. However, you can use the **CloudWS-bootc userland** (all your packages, configs, and tools) as a WSL2 distribution.

## Method 1: Rootfs Export (Recommended)
This method exports the container's filesystem and imports it as a standard WSL distribution.

### 1. Build or Pull the Image
```bash
podman pull ghcr.io/your-user/cloudws-bootc:latest
```

### 2. Export the Rootfs
```bash
podman export $(podman create ghcr.io/your-user/cloudws-bootc:latest) -o cloudws-bootc.tar
```

### 3. Import into WSL (PowerShell)
```powershell
wsl --import CloudWS-bootc C:\WSL\CloudWS-bootc .\cloudws-bootc.tar
```

### 4. Configure the User
Since WSL2 starts as `root` by default, update `/etc/wsl.conf` inside the new distro to set your user:
```ini
[user]
default=cloudws
```

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
podman-bootc run --image ghcr.io/your-user/cloudws-bootc:latest
```

---

## Known Limitations in WSL2
- **NVIDIA GPU:** WSL2 uses its own `libdxcore` and `/dev/dxg` for GPU acceleration. The NVIDIA drivers in the `bootc` image (kernel modules) will not load. You must use the host's Windows drivers mapped into WSL2.
- **Systemd:** Ensure systemd is enabled in `/etc/wsl.conf` if using the rootfs export method.
