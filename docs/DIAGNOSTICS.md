# Logging & Diagnostics Guide

This document explains where to find system logs in CloudWS-bootc, how to diagnose common issues, and how to collect a diagnostic bundle for support.

## System Journal

CloudWS uses systemd-journald as the primary logging system. All service logs, kernel messages, and application output flow through the journal.

### Viewing logs

```bash
# Current boot (most common)
journalctl -b

# Previous boot (useful after a crash)
journalctl -b -1

# Follow live logs
journalctl -f

# Last 100 lines
journalctl -n 100

# Since a specific time
journalctl --since "2026-04-13 10:00:00"

# Last hour
journalctl --since "1 hour ago"
```

### Filtering by service

```bash
# Specific service
journalctl -u gdm
journalctl -u libvirtd
journalctl -u cockpit
journalctl -u crowdsec
journalctl -u podman

# GPU auto-detect service
journalctl -u cloudws-gpu-detect

# NVIDIA CDI refresh
journalctl -u nvidia-cdi-refresh

# bootc updates
journalctl -u bootc-fetch-apply-updates
```

### Filtering by priority

```bash
# Errors and worse only
journalctl -p err

# Warnings and worse
journalctl -p warning

# Critical only
journalctl -p crit
```

## Key Log Locations

| What | Command / Path |
|------|---------------|
| System journal | `journalctl` |
| Management Dashboard | `/usr/libexec/cloudws/motd` |
| Active Role State | `/var/lib/cloudws/role.active` |
| Build log (during image build) | `/tmp/cloudws-build.log` |
| SELinux denials | `ausearch -m AVC -ts recent` |
| Firewall drops | `journalctl -u firewalld` and `nft list ruleset` |
| CrowdSec decisions | `sudo cscli decisions list` |
| CrowdSec alerts | `sudo cscli alerts list` |
| Podman containers | `podman logs <container>` |
| Libvirt VMs | `journalctl -u libvirtd` and `/var/log/libvirt/qemu/` |
| GNOME session | `journalctl --user -u gnome-session` |
| Cockpit | `journalctl -u cockpit` |
| NetworkManager | `journalctl -u NetworkManager` |
| Secure Boot | `mokutil --sb-state` |
| bootc status | `sudo bootc status --json` |

## Common Diagnostic Commands

### System overview

```bash
# OS version and deployment status
sudo bootc status
cat /etc/cloudws/version

# Current Role and Target
cat /var/lib/cloudws/role.active
systemctl list-units --type=target | grep cloudws

# Run the management dashboard manually
/usr/libexec/cloudws/motd

# Kernel and architecture
uname -a
```
# systemd boot analysis
systemd-analyze
systemd-analyze blame
systemd-analyze critical-chain

# Failed services
systemctl --failed
```

### GPU diagnostics

```bash
# All GPUs detected
lspci -nnk | grep -A 3 -E "VGA|3D|Display"

# NVIDIA status
nvidia-smi
nvidia-smi -q

# NVIDIA CDI specs
cat /etc/cdi/nvidia.yaml

# Mesa/AMD/Intel
glxinfo | head -20
vulkaninfo --summary

# VFIO readiness
cloudws-vfio-check
```

### Virtualization diagnostics

```bash
# KVM capability
virt-host-validate

# Libvirt status
virsh list --all
virsh nodeinfo

# IOMMU groups
find /sys/kernel/iommu_groups/ -type l | sort -t/ -k5 -n

# Looking Glass
journalctl -u looking-glass-kvmfr
ls -la /dev/kvmfr0
```

### Container diagnostics

```bash
# Podman status
podman info
podman ps -a

# K3s status
sudo k3s kubectl get nodes
sudo k3s kubectl get pods -A

# Quadlet units
systemctl list-units 'podman-*'
ls /usr/share/containers/systemd/
ls /etc/containers/systemd/
```

### Network diagnostics

```bash
# NetworkManager connections
nmcli connection show
nmcli device status

# DNS resolution
resolvectl status

# Firewall
sudo firewall-cmd --list-all
sudo nft list ruleset

# CrowdSec
sudo cscli metrics
```

### Storage diagnostics

```bash
# Disk usage
df -h
lsblk

# bootc deployments
sudo bootc status

# Ceph (if configured)
sudo ceph status
sudo ceph osd tree

# Podman storage
podman system df
```

### SELinux diagnostics

```bash
# Current mode
getenforce

# Recent denials
sudo ausearch -m AVC -ts recent

# Analyze a denial
sudo ausearch -m AVC -ts recent | audit2why

# Generate a policy fix suggestion
sudo ausearch -m AVC -ts recent | audit2allow -M fix_module

# CloudWS custom policies
sudo semodule -l | grep cloudws

# Check booleans
getsebool -a | grep -E "container_use_cephfs|virt_use_samba"
```

## Collecting a Diagnostic Bundle

When filing a bug report, collect the following:

```bash
# Create a diagnostic bundle
mkdir -p /tmp/cloudws-diag
cd /tmp/cloudws-diag

# System info
sudo bootc status > bootc-status.txt 2>&1
uname -a > kernel.txt
cat /etc/cloudws-version > version.txt 2>/dev/null
rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort > packages.txt

# Journal (last boot, errors only)
journalctl -b -p err --no-pager > journal-errors.txt 2>&1

# Failed services
systemctl --failed --no-pager > failed-services.txt

# GPU
lspci -nnk | grep -A 3 -E "VGA|3D|Display" > gpu-pci.txt
nvidia-smi > nvidia-smi.txt 2>&1 || echo "No NVIDIA" > nvidia-smi.txt

# SELinux
getenforce > selinux-mode.txt
sudo ausearch -m AVC -ts boot --no-pager > selinux-denials.txt 2>&1

# Boot timing
systemd-analyze > boot-timing.txt 2>&1
systemd-analyze blame --no-pager | head -30 >> boot-timing.txt

# Firewall
sudo firewall-cmd --list-all > firewall.txt 2>&1

# Tar it up
cd /tmp
tar czf cloudws-diag-$(date +%Y%m%d).tar.gz cloudws-diag/
echo "Bundle: /tmp/cloudws-diag-$(date +%Y%m%d).tar.gz"
```

Attach the resulting tarball to your GitHub issue.

## Cockpit Web Console

CloudWS includes Cockpit for browser-based system management. Access it at:

```
https://localhost:9090
```

Cockpit provides graphical views of system logs, performance metrics, storage, networking, containers (Podman), and virtual machines (libvirt) — often easier than command-line diagnostics for quick triage.

## Performance Diagnostics

```bash
# CPU frequency and governor
cpupower frequency-info

# TuneD active profile
tuned-adm active
tuned-adm recommend

# I/O latency
iostat -xz 1 5

# Memory pressure
vmstat 1 5

# Process resource usage
top -bn1 | head -20
```
