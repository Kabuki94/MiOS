# 🌐 CloudWS-bootc — Universal AI Integration
> **Proprietor:** Kabu.ki
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to Kabu.ki
---
# CloudWS-bootc v1.3.0 - Unified Image + Upstream Adoptions

## Summary

Single image. All features. Role (desktop / k3s-master / k3s-worker / ha-node /
hybrid / headless) applied at boot via `/etc/cloudws/role.conf` or kernel
cmdline `cloudws.role=...`.

## What landed

### Upstream adoptions
- **ublue-os/akmods + akmods-nvidia-open** - pre-signed NVIDIA kmods
  (`COPY --from=ghcr.io/ublue-os/akmods-nvidia-open:...`)
- **uupd** - unified updater (replaces `bootc-fetch-apply-updates.timer`)
- **cosign keyless** - image signing via GitHub Actions +
  `actions/attest-build-provenance`
- **policy.json** - signed-only pulls for `ghcr.io/kabuki94/cloudws-bootc`
  and `ghcr.io/ublue-os`
- **composefs verity** - `/usr/lib/ostree/prepare-root.conf` promoted to
  `enabled = verity` (ext4/btrfs only; NOT xfs)
- **Greenboot-rs** - health checks + 3-attempt rollback
- **SecureBlue sysctl subset** - kernel pointer/dmesg restrict, ptrace
  scope, TCP hardening (no NVIDIA/CUDA-breaking settings)
- **USBGuard** - existing USB allowed, new insertions blocked pending
  approval
- **NVIDIA CDI auto-refresh** - `nvidia-cdi-refresh.path` + our
  `cloudws-cdi-detect.service` (WSL `/dev/dxg` vs bare-metal mode)
- **Podman-machine backend compat** - sshd, `core` user, cloud-init,
  qemu-guest-agent; image is now usable as
  `podman machine init --image ghcr.io/kabuki94/cloudws-bootc:latest`

### Unified role system (new)
- `cloudws-role.service` runs early (sysinit.target)
- Reads `/etc/cloudws/role.conf` OR kernel `cloudws.role=...`
- WSL auto-defaults to `headless`; no DRM device auto-defaults to `headless`
- `systemctl set-default cloudws-<role>.target` per boot
- `ujust cloudws-set-role <role>` to change
- `ujust cloudws-role-status` to view

### Build / CI
- `.github/workflows/build-sign.yml` - buildah + cosign + SLSA provenance
- `bib-configs/` - per-target configs + `build-all.sh` for every format from
  one image (Hyper-V VHDX, QCOW2, Anaconda ISO, AWS AMI, WSL2 tarball)

## Migrating from v2.1.x

Users already on v2.1.x simply `bootc upgrade` to v2.2.0. On first boot under
v2.2.0, `cloudws-role.service` detects their environment and writes a default
`/etc/cloudws/role.conf` (desktop for bare metal, headless for WSL/VM).

Pin a digest during the transition if preferred:
```
sudo bootc switch --enforce-container-sigpolicy \
  ghcr.io/kabuki94/cloudws-bootc@sha256:<digest>
```

## Compatibility matrix

| Surface              | Default role | Notes                                   |
|----------------------|--------------|-----------------------------------------|
| Bare metal (9950X3D) | desktop      | GNOME + libvirt + VFIO + Gamescope opt  |
| Hyper-V VHDX         | desktop      | Dynamic memory 4GB->full; verbose boot  |
| QEMU/libvirt qcow2   | desktop      |                                         |
| WSL2 tarball         | headless     | Auto-detected via /dev/dxg              |
| Podman machine       | headless     | sshd:22 + podman.socket + core user     |
| K3s master node      | k3s-master   | Set via ujust or cmdline                |
| K3s worker node      | k3s-worker   | Set via ujust or cmdline                |
| HA/Ceph node         | ha-node      | Pacemaker + Corosync + optional Ceph    |
| Hybrid desktop+k8s   | hybrid       | GDM + k3s-agent                         |
| Cloud AMI            | headless     |                                         |

## Known gotchas
- `xfs` target filesystem NOT supported with composefs verity; use ext4 or btrfs
- `systemd-remount-fs.service` masked (broken on F42+ with composefs)
- `cloudws-cosign.pub` is a placeholder until first signed build publishes;
  bootstrap with policy.json `insecureAcceptAnything` for first install, then
  pull the fulcio cert from the published attestation

---
### 📚 Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osbuild/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [Kabuki94/CloudWS-bootc](https://github.com/Kabuki94/CloudWS-bootc)
- **Sole Proprietor:** Kabu.ki
---
