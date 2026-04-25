# GPU Passthrough Architecture (CloudWS-bootc v1.3.0)

CloudWS-bootc ships universal container-runtime GPU passthrough plumbing for
NVIDIA, AMD, and Intel GPUs, designed to work identically across bare metal,
Hyper-V VHDX, QEMU/libvirt, WSL2, and Cockpit deployments.

---

## Decision log

### Architectural Purity: Everything in the Overlay

As of **v1.3.0**, CloudWS has consolidated all system configuration into the
`system_files/` overlay. Redundant root-level directories for systemd, udev,
and kargs have been removed. This ensures a **Single Source of Truth** and
eliminates build failures caused by path desynchronization.

### CDI specs live in `/var/run/cdi/`, not `/etc/cdi/`

Writing runtime hardware state into `/etc` creates merge conflicts across
upgrades. CloudWS uses `/var/run/cdi/` (tmpfs) which is cleared on boot,
ensuring driver versions and topology are always fresh.

### SELinux: `container_use_devices=on`

The correct minimal-privilege path for GPU access is the `container_use_devices`
boolean. CloudWS persists this at build time via `semanage boolean` and
re-sets it at each boot via `cloudws-gpu-status.service` as a safety net.

---

## Files delivered by v1.3.0 (System Overlay)

All passthrough components are delivered exclusively via the `system_files/`
overlay.

```
scripts/34-gpu-detect.sh                                   # first-boot detector
scripts/35-gpu-passthrough.sh                              # build-time wiring
system_files/usr/libexec/cloudws/gpu-detect                # detection logic
system_files/usr/lib/systemd/system/cloudws-gpu-status.service  # umbrella oneshot
system_files/usr/lib/systemd/system/cloudws-gpu-nvidia.service  # NVIDIA plumbing
system_files/usr/lib/systemd/system/cloudws-gpu-amd.service     # AMD KFD/DRI
system_files/usr/lib/systemd/system/cloudws-gpu-intel.service    # Intel DRI
system_files/usr/lib/systemd/system/nvidia-cdi-refresh.service.d/10-cloudws-ordering.conf
system_files/usr/lib/udev/rules.d/99-cloudws-gpu.rules     # device perms
system_files/usr/lib/tmpfiles.d/cloudws-gpu.conf           # runtime dirs
system_files/usr/lib/sysusers.d/50-cloudws-gpu.conf        # render/video GIDs
system_files/usr/lib/bootc/kargs.d/02-cloudws-gpu.toml     # iommu=pt + nouveau blk
docs/gpu-passthrough.md                                    # this file
```
