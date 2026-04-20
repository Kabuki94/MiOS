# CloudWS-bootc v0.1.8 - Truly fix the broken bits

## Bugs this release fixes

### 1. Containerfile still had broken akmods FROM stages

v2.2.1 was supposed to remove `FROM ghcr.io/ublue-os/akmods-nvidia-open:main-rawhide-580`
and the companion akmods-common / akmods-extra stages - that tag does not
exist, and ucore-hci:stable-nvidia already ships NVIDIA kmods baked in.

v2.2.1 never actually committed (user went v2.2.0 -> v2.2.2 directly, v2.2.1
push either failed or was skipped). CI has been failing ever since on
`manifest unknown`.

**Fixed**: Containerfile now has a single `FROM ${BASE_IMAGE}` (default
ucore-hci:stable-nvidia) with no external akmod pulls.

### 2. PACKAGES.md additions block was invisible to the parser

v2.2.3 merged `PACKAGES-UNIFIED-EXTRAS.md` into PACKAGES.md between
`<!-- CLOUDWS_V2_ADDITIONS_BEGIN/END -->` markers. But the fenced code blocks
inside used plain ` ``` ` fences - not the ` ```packages-<category> ` tagged
format that `scripts/lib/packages.sh` requires (it uses a sed pattern
anchored on `` ```packages-${category}$ ``).

Net effect: every package I "added" in v2.2.0 was silently ignored by
packages.sh. uupd, greenboot, cosign, nvidia-container-selinux, aide,
openscap-scanner, cloud-init, wslu, kubectl, helm, toolbox, steam-devices,
freerdp, virt-viewer, libei - all skipped.

**Fixed**:
- Stripped the entire `CLOUDWS_V2_ADDITIONS_BEGIN/END` block.
- Added the genuinely-new packages to the **existing tagged sections** that
  packages.sh actually parses:
  - `packages-security` += aide, openscap-scanner, scap-security-guide,
    libpwquality, nftables, policycoreutils, setools-console
  - `packages-containers` += podman-plugins, podman-docker, containers-common,
    toolbox, cosign, kubectl, helm
  - `packages-gpu-nvidia` += nvidia-container-selinux
  - `packages-virt` += virt-viewer, qemu-device-display-virtio-gpu
  - `packages-gaming` += steam-devices
  - `packages-wintools` += freerdp, freerdp-libs
  - `packages-utils` += wslu, python3-pip, cloud-init, libei
- Added one genuinely-new section:
  - `packages-updater` (new): uupd, greenboot, greenboot-default-health-checks
  - Wired into scripts/43-uupd-installer.sh via `install_packages "updater"`

### 3. PACKAGES.md referenced a deleted file

The stripped block contained text: "The build pipeline parses both
PACKAGES.md and PACKAGES-UNIFIED-EXTRAS.md." The second file was deleted in
v2.2.3. That sentence was a lie.

**Fixed**: the whole block is gone.

### 4. 40-series scripts duplicated PACKAGES.md with inline `dnf install`

Every script from 41 through 47 had its own `dnf5 -y install ...` block
listing packages that should live in PACKAGES.md. Two sources of truth for
the same packages is exactly the problem you've been calling out.

**Fixed**: scripts/41-47 now do ONLY service wiring, config-file writing,
and user creation. All package installs go through PACKAGES.md -> packages.sh.

Specifically:
- `41-akmods-copy.sh`: now verification-only (confirms kmod-nvidia* + MOK
  cert present from ucore-hci base). No /tmp/akmods-* paths anymore since
  Containerfile doesn't create them.
- `42-cosign-policy.sh`: now verification-only (cosign is in
  packages-containers).
- `43-uupd-installer.sh`: `install_packages "updater"` +
  `systemctl enable uupd.timer` + disable superseded timers.
- `44-podman-machine-compat.sh`: `core` user creation + sshd/podman.socket/
  qemu-guest-agent/cloud-init service enables. Zero dnf calls.
- `45-nvidia-cdi-refresh.sh`: service enables only.
- `46-greenboot.sh`: service enables + /etc/greenboot/greenboot.conf only.
- `47-hardening.sh`: `systemctl enable usbguard.service auditd.service`
  only. Zero dnf calls.

## Verify

After `bootc upgrade` to v2.2.4:

```
rpm -q uupd greenboot greenboot-default-health-checks cosign nvidia-container-selinux
rpm -q aide openscap-scanner cloud-init wslu kubectl helm steam-devices freerdp
systemctl is-enabled uupd.timer
systemctl is-enabled cloudws-cdi-detect.service
```

Every one should return positive.

## Commit message via file (not -m)

v2.2.3 crashed on `git commit -m @"..."@` because PowerShell->git.exe argument
parsing splits multi-line strings at whitespace. This script uses
`git commit -F <tempfile>` which handles multi-line correctly.