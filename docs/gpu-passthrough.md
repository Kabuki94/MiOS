# GPU Passthrough Architecture (CloudWS-bootc v2.1.5)

CloudWS-bootc ships universal container-runtime GPU passthrough plumbing for
NVIDIA, AMD, and Intel GPUs, designed to work identically across bare metal,
Hyper-V VHDX, QEMU/libvirt, WSL2, and Cockpit deployments. This document
describes the architecture, runtime model, and the "why" behind each decision.

---

## Decision log

### CDI specs live in `/var/run/cdi/`, not `/etc/cdi/`

`/etc` is composefs-managed on bootc and subject to OSTree's 3-way merge
between `/usr/etc`, the running `/etc`, and the next deployment's `/usr/etc`.
Writing runtime hardware state into `/etc` creates merge conflicts and spec
drift across upgrades.

`/var/run` is a symlink to `/run` (tmpfs) and is intentionally cleared on
boot, which is exactly what CDI wants — driver versions, device UUIDs, and
topology can change between boots. Podman's default `cdi_spec_dirs` is
`["/etc/cdi", "/var/run/cdi"]`, so dropping the spec into `/var/run/cdi/`
needs no containers.conf change.

### NVIDIA: delegate to upstream `nvidia-cdi-refresh.service`

As of `nvidia-container-toolkit >= 1.18.0`, NVIDIA ships
`nvidia-cdi-refresh.service` + `nvidia-cdi-refresh.path`. The `.path` unit
watches `/dev/nvidia*`; the `.service` runs
`nvidia-ctk cdi generate --output=/var/run/cdi/nvidia.yaml`.

CloudWS does not re-implement this. We enable the upstream units at build
time (via symlink in `multi-user.target.wants`) and ship a drop-in that
neutralizes the `After=multi-user.target` ordering cycle introduced in
v1.19.0 (upstream issue #1735). Our own `cloudws-gpu-nvidia.service` only
fires the modprobe chain and creates `/var/run/cdi`; it defers actual
generation to NVIDIA when their service is present, and falls back to a
direct `nvidia-ctk cdi generate` call on images without it.

### AMD: explicit device flags, not CDI

The AMD Container Toolkit (`amd-ctk`) exists upstream at
`github.com/ROCm/container-toolkit` but has no Fedora RPM yet. Rather than
add a third-party repo to an immutable image, CloudWS stays on explicit
device flags:

```bash
podman run --device /dev/kfd --device /dev/dri --group-add keep-groups ...
```

`cloudws-gpu-amd.service` auto-detects `amd-ctk` if it ever lands and will
generate `/var/run/cdi/amd.json` — no image revision needed on the CloudWS
side when that happens.

### Intel: explicit device flags, default SELinux

Intel CDI generation exists in `intel-device-plugins-for-kubernetes` but is
K8s-centric and not appropriate for standalone Podman. Intel iGPUs and Arc
dGPUs work with:

```bash
podman run --device /dev/dri/renderD128 --group-add keep-groups ...
```

### SELinux: `container_use_devices=on`, NOT `container_runtime_t`

A common anti-pattern in AMD ROCm guides is passing
`--security-opt label=type:container_runtime_t` to grant containers access
to `/dev/kfd`. That label is the domain for the container **runtime itself**
(runc/crun/conmon) and gives the workload runtime-level SELinux privileges
— a significant escalation.

The correct minimal-privilege path is the `container_use_devices` boolean,
which grants `container_t` read/write/map on the device classes involved.
CloudWS persists this at build time via `semanage boolean` and re-sets it
at each boot via `cloudws-gpu-status.service` as a safety net.

### kargs.d: flat `kargs = [...]` only

bootc's kargs.d TOML parser requires a flat top-level `kargs` array. There
is no `[kargs]` section header and no delete mechanism. Any file with
`[kargs]` section syntax silently fails. CloudWS ships
`kargs.d/02-cloudws-gpu.toml` with `iommu=pt` and nouveau blacklist —
universally safe. NVIDIA-specific modeset args live in `modprobe.d`
options files, never kargs, because they crash early boot on hardware
without the NVIDIA module loaded.

---

## Runtime boot chain

1. **initrd / `systemd-modules-load.service`** loads `nvidia` / `amdgpu` /
   `i915` based on what's present. The `34-gpu-detect.sh` built-in removes
   the NVIDIA module blacklist on bare metal (bootc first-boot script).
2. **udev** fires `/usr/lib/udev/rules.d/99-cloudws-gpu.rules`, pinning
   perms on `/dev/dri/*`, `/dev/kfd`, and `/dev/nvidia*`.
3. **`cloudws-gpu-status.service`** (Type=oneshot, umbrella) writes
   `/run/cloudws/gpu-passthrough.status` with detected vendors and
   virtualization type; re-asserts the `container_use_devices` boolean.
4. **`cloudws-gpu-{nvidia,amd,intel}.service`** run in parallel, each
   `ConditionPathExists`-guarded on its device node
   (`/dev/nvidia0`, `/dev/kfd`, `/dev/dri/renderD128`). Non-matching units
   are silently skipped — a VM without GPU reports cleanly in
   `systemctl status`, no errors.
5. **`nvidia-cdi-refresh.path`** (CloudWS-2 only) fires the moment NVIDIA
   character devices appear, triggering `nvidia-cdi-refresh.service` which
   writes `/var/run/cdi/nvidia.yaml`.
6. **`podman.socket` / `docker.socket`** activate with CDI specs already
   in place.

### VM behavior (no GPU)

All three vendor `ConditionPathExists` checks fail silently. The detect
service still runs and writes:

```
timestamp=2026-04-17T12:34:56Z
virtualization=kvm
nvidia=0
amd=0
intel=0
```

No boot failure, no error spam, no wasted time.

---

## Vendor runtime table

| Vendor | CDI? | Container flags | Groups | SELinux |
|---|---|---|---|---|
| **NVIDIA (bare metal)** | Yes, via `nvidia-cdi-refresh.service` | `--device nvidia.com/gpu=all` | none (CDI handles) | default `container_t` is fine; CDI handles device relabel |
| **NVIDIA (WSL2)** | Yes, `nvidia-ctk --mode=wsl` | `--device nvidia.com/gpu=all --security-opt=label=disable` | none | disable |
| **AMD (bare metal)** | Future (no Fedora RPM yet) | `--device /dev/kfd --device /dev/dri --group-add keep-groups` | user in `render` AND `video` | `container_use_devices=on` |
| **AMD (WSL2)** | No KFD on WSL; use `librocdxg` | `--device /dev/dxg` + librocdxg mounts | n/a | disable |
| **Intel (bare metal)** | K8s-only for now | `--device /dev/dri/renderD128 --group-add keep-groups` | `render` | `container_use_devices=on` |
| **Intel (WSL2)** | Not supported | n/a | n/a | n/a |

---

## Troubleshooting

### "My container can't see the GPU"

```bash
# 1. Check the status file
cat /run/cloudws/gpu-passthrough.status

# 2. Check vendor service state
systemctl status cloudws-gpu-status \
                 cloudws-gpu-nvidia \
                 cloudws-gpu-amd \
                 cloudws-gpu-intel

# 3. NVIDIA only: check CDI spec exists
ls -l /var/run/cdi/
journalctl -u nvidia-cdi-refresh -u nvidia-cdi-refresh.path --no-pager

# 4. List CDI devices Podman knows about
podman info --format '{{range .Host.CDISpecs}}{{.Name}}
{{end}}'

# 5. SELinux boolean state
getsebool container_use_devices
```

### "nvidia-cdi-refresh.service won't start / ordering cycle"

If the upstream service misbehaves, check our drop-in is in place:

```bash
systemctl cat nvidia-cdi-refresh.service
# Should show the 10-cloudws-ordering.conf drop-in clearing After=multi-user.target
```

### "My VM hangs on boot after adding this"

v2.1.5 deliberately keeps kargs minimal. If you added `nvidia-drm.modeset=1`
to kargs.d yourself, move it to a `modprobe.d` options file instead.

### "AMD container can't access /dev/kfd despite being in render group"

Check SELinux:

```bash
getsebool container_use_devices        # should be "on"
sudo setsebool -P container_use_devices on
ausearch -m AVC -ts recent | tail -20  # look for denied { read write } on xserver_misc_device_t
```

---

## Files delivered by v2.1.5

```
scripts/35-gpu-passthrough.sh                              # build-time installer
scripts/cloud-ws-builder.ps1                               # Windows-side builder
systemd/cloudws-gpu-status.service                         # umbrella oneshot
systemd/cloudws-gpu-nvidia.service                         # NVIDIA plumbing
systemd/cloudws-gpu-amd.service                            # AMD KFD/DRI
systemd/cloudws-gpu-intel.service                          # Intel DRI
systemd/nvidia-cdi-refresh.service.d/10-cloudws-ordering.conf  # #1735 workaround
udev/99-cloudws-gpu.rules                                  # device perms
tmpfiles.d/cloudws-gpu.conf                                # runtime dirs
sysusers.d/50-cloudws-gpu.conf                             # render=105 / video=39
kargs.d/02-cloudws-gpu.toml                                # iommu=pt + nouveau blk
docs/gpu-passthrough.md                                    # this file
```
