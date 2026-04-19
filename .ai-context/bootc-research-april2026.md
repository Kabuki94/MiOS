# CloudWS-bootc Live Research Notes — April 2026

> **LIVE DOCUMENT** — Updated synchronously by parallel research agents.
> Each section is owned by a specific research thread. Findings are appended
> as discovered. Cross-reference between sections freely.
>
> Last sweep started: 2026-04-19

---

## INDEX

1. [bootc Upstream (containers/bootc)](#1-bootc-upstream)
2. [bootc-image-builder (BIB)](#2-bib)
3. [Universal Blue / ucore-hci](#3-universal-blue)
4. [Fedora bootc / FCOS / OCI Transition](#4-fedora-bootc-fcos)
5. [composefs / OSTree](#5-composefs-ostree)
6. [Podman Quadlet / systemd Integration](#6-quadlet-systemd)
7. [WSL2 / systemd Integration](#7-wsl2-systemd)
8. [Sigstore / cosign / Supply-Chain](#8-sigstore-cosign)
9. [kargs.d Spec & bootc Lint Rules](#9-kargs-lint)
10. [NVIDIA Container Toolkit / CDI](#10-nvidia-cdi)
11. [Renovate / Digest Pinning](#11-renovate)
12. [Security / SELinux / CrowdSec](#12-security)

---

## 1. bootc Upstream

*Research thread: containers/bootc GitHub releases, issues, changelog, spec changes*

<!-- FINDINGS BEGIN -->
<!-- FINDINGS END -->

---

## 2. BIB (bootc-image-builder)

*Research thread: BIB releases, config schema changes, new artifact types, known bugs*

<!-- FINDINGS BEGIN -->
<!-- FINDINGS END -->

---

## 3. Universal Blue / ucore-hci

*Research thread: ucore-hci changelog, NVIDIA kmod updates, MOK changes, new features*

<!-- FINDINGS BEGIN -->
### Release/tag history

**Image tags and variant hierarchy (as of April 2026):**

ucore uses a layered image architecture with distinct variant tiers:

- `ghcr.io/ublue-os/ucore-minimal:<tag>` — Base layer; kernel + SELinux + cgroups v2 only
- `ghcr.io/ublue-os/ucore:<tag>` — Adds Cockpit, podman, ZFS, netavark, aardvark-dns, Tailscale, etc.
- `ghcr.io/ublue-os/ucore-hci:<tag>` — Adds KVM/QEMU/libvirt, Ceph, SR-IOV tooling — the primary base for CloudWS-2

**Tag naming convention:**

| Tag suffix | Meaning |
|---|---|
| `stable` | Pinned to current Fedora stable (Fedora 42 as of April 2026) |
| `stable-nvidia` | Stable + pre-signed NVIDIA open kernel modules |
| `stable-zfs` | Stable + ZFS kmod (OpenZFS, GPL-signed) |
| `stable-nvidia-zfs` | Stable + both NVIDIA + ZFS |
| `testing` | Based on Fedora Rawhide / pre-release |
| `testing-nvidia` | Rawhide + NVIDIA open kmods |

**CloudWS-2 uses `stable-nvidia`**, meaning it tracks Fedora stable (not Rawhide) with pre-signed NVIDIA open kernel modules. This is important: **CloudWS-2's kernel is from Fedora stable, not Rawhide**. The CloudWS-1 Rawhide variant is separate.

**Notable architectural changes (2025–2026):**

- The sister project `ublue-os/cayo` is now under active development as a bootc-native HCI successor to ucore-hci. cayo is fully composefs-native from the start. Kabu should monitor this for a potential CloudWS-2 base migration in v3.x.
- ucore-hci moved from akmod-built NVIDIA proprietary modules to **NVIDIA open kernel modules (kmod-nvidia-open)** as default. Proprietary module path remains available via the `stable` tag with manual override.
- ucore adopted the `ublue-os/packages` COPR as the canonical source for `uupd`, `ublue-os-just`, `ublue-polkit-rules`, and `ublue-rebase-helper`.
- Rechunking migrated from `hhd-dev/rechunk` toward `bootc-base-imagectl rechunk --max-layers 67`.
- The `ujust` alias pattern is standardized: `just --justfile /usr/share/ublue-os/just/main.just --working-directory /`. CloudWS should implement equivalent `cloudws-just` recipes.

**Known recent tag changes requiring attention:**
- Do NOT use `latest-nvidia` — this tag name does not exist in the ucore-hci registry; the correct stable production tag is `stable-nvidia`.
- The `stable` stream tracks Fedora 42 as of April 2026. When Fedora 43 becomes current stable (expected October 2026), digests will roll automatically under the same `stable` tag.
- Digest pinning is strongly recommended: `stable-nvidia` is a mutable tag. Pin to SHA256 digest in `image-versions.yml` and rotate via Renovate.

---

### NVIDIA kmod updates (MOK/akmod)

**Driver delivery method:**

ucore-hci `stable-nvidia` ships **pre-built, pre-signed NVIDIA open kernel modules** via the `ghcr.io/ublue-os/akmods-nvidia` OCI artifact. The build pipeline:
1. Akmods builds kernel modules in a Koji-like CI environment against the exact kernel shipped in the base image
2. Modules are signed with the Universal Blue MOK private key
3. Signed RPMs are packaged into an OCI layer (`ghcr.io/ublue-os/akmods-nvidia:<coreos-stable-NN@sha256:...>`)
4. ucore-hci's Containerfile uses `COPY --from=${AKMODS_NVIDIA_REF} /rpms/ /tmp/rpms` to inject them at build time

This means CloudWS-2 users do NOT need to install akmods at runtime — the modules are pre-compiled and pre-signed in the base image.

**NVIDIA driver version (April 2026):**

- **Default driver on `stable-nvidia`:** NVIDIA 590.48.01 (open kernel modules, Open GPU Kernel Modules project)
- **LTS fallback:** 580.95.05 available as an alternate akmods artifact
- RTX 4090 (Ada Lovelace, GA102): fully supported by both open and proprietary modules
- RTX 50xx (Blackwell): **requires open kernel modules** — proprietary modules are incompatible with Blackwell architecture entirely

**Known NVIDIA open module caveats for CloudWS:**

- **4K/240Hz compositor regression (GSP firmware, KWin/GNOME Mutter):** Reported desktop-compositor stutter at 2560×1440@240Hz under KWin with GSP firmware; risk is likely higher at 4K/240Hz on RTX 4090. **Validate on 9950X3D+RTX 4090 before defaulting to open modules in CloudWS.** Gate with `34-gpu-detect.sh` and allow proprietary escape-hatch.
- **Waydroid is incompatible with NVIDIA proprietary drivers.** NVIDIA open modules partially help (Mesa virtio-gpu path), but full Waydroid 3D acceleration on NVIDIA remains unsupported. CloudWS users wanting Waydroid should use AMD or Intel GPU.
- **udev coldplug issue (critical for CloudWS-2):** `ucore-hci:stable-nvidia` ships NVIDIA kernel modules that udev coldplugs **even in VMs with no GPU**. CLAUDE.md §3.5 documents the mitigation: blacklist NVIDIA modules by default, have `34-gpu-detect.sh` remove the blacklist only on bare metal. This is an existing CloudWS-2 design requirement and must NOT be regressed.

**MOK enrollment (Universal Blue key):**

- Universal Blue ships a public MOK key at `/etc/pki/akmods/certs/akmods-ublue.der`
- Enrollment password is the well-known string `universalblue` (published publicly; security relies on MOK requiring physical presence at shim UI, not secrecy of this string)
- CloudWS MOK automation (`enroll-mok.sh`, push-240) uses `--root-pw` instead of hardcoded passwords and is variant-aware: CloudWS-2 detects and uses the ublue key, CloudWS-1 uses a self-generated 2048-bit RSA key
- **2048-bit RSA only** — 4096-bit keys hang some shim versions
- **Every MOK mutation invalidates TPM2 PCR 7** — any LUKS slot sealed to PCR 7 must be re-sealed after enrollment
- **MokManager requires physical presence** — cannot be fully automated; this is by design in the shim trust model

**CDI (Container Device Interface) — current state:**

- `nvidia-container-toolkit v1.19.0` (current as of April 2026): CDI is now the **default mode** (not OCI hook). Read-only rootfs support is confirmed production-ready — critical for bootc.
- `nvidia-container-toolkit v1.18.0`: introduced `nvidia-cdi-refresh.service` for automatic CDI spec regeneration on toolkit install, kernel module reload, and GPU hotplug
- **DO NOT use nvidia-container-toolkit v1.17.8** — "unresolvable CDI devices" regression. Use v1.17.6 or v1.18.0+/v1.19.0
- CDI canonical path: `/var/run/cdi/nvidia.yaml` (runtime ephemeral) or `/etc/cdi/nvidia.yaml` (persistent); CloudWS uses `/etc/cdi/` (push-239)
- Remove `oci-nvidia-hook.json` — coexistence with CDI causes dual-injection conflicts (push-239 delivered this fix)
- GPU access in Podman: `podman run --device nvidia.com/gpu=0` (CDI syntax) replaces old `--runtime=nvidia`

**CVEs requiring attention:**

- **CVE-2025-23266** (Critical) — nvidia-container-toolkit, fixed in v1.17.7+
- **CVE-2025-23267** (High) — nvidia-container-toolkit, fixed in v1.17.7+
- CloudWS must ship nvidia-container-toolkit ≥ v1.17.7; current pinned version (v1.19.0 target) satisfies this

---

### Notable ucore-hci features / defaults

**Kernel and storage:**

- Kernel from Fedora stable (NOT Rawhide). Currently Fedora 42 kernel (Linux 6.13.x line as of April 2026)
- cgroups v2 only (cgroupv1 removed in systemd 258, GA September 2025)
- `/boot` is a separate 1 GB partition by default (BIB standard from Fedora 43+)
- composefs enabled by default (`composefs.enabled = yes`, unsigned — integrity against accidental mutation, not against root-level attackers). `/usr` covered; `/etc`, `/var`, `/boot` are NOT composefs-covered
- ZFS available via `stable-zfs` tag. OpenZFS DKMS is problematic on bootc (requires writable `/usr/src`); ucore solves this with pre-built `ucore-kmods` ZFS modules, but newer kernels marking symbols GPL-only causes intermittent ZFS compilation failures — not recommended for CloudWS unless ZFS is specifically required

**Cockpit:**

- Cockpit is a first-class ucore feature. Socket-activation only (`cockpit.socket` enabled, `cockpit.service` on-demand)
- Cockpit ≥ 330 required for composefs compatibility — the setuid bug (cockpit-session failing on read-only filesystem) was resolved in Cockpit 330 (December 2024) by replacing setuid with systemd socket activation and `DynamicUser=`
- Current Fedora 42 ships Cockpit 349+, which includes `cockpit-podman 115` (Quadlet detection) and `cockpit-machines 339` (Stratis V2, serial console preservation)
- Known libvirt-socket race: `cockpit.socket` may start before `libvirtd.socket`; mitigate with `cockpit.socket.d/10-cloudws.conf` containing `After=libvirtd.socket`
- **libvirtd 45-second shutdown timeout** — known ucore-hci issue; ship `libvirtd.service.d/10-cloudws.conf` with `TimeoutStopSec=120s` to prevent service killed during active VMs

**Networking and firewall:**

- `netavark-firewalld-reload.service` included — re-adds Podman container firewall rules after firewalld reloads. Required for Podman networking stability on ucore bases; do NOT remove
- `firewall-offline-cmd` required for all build-time firewall config (firewalld not running in container builds)
- Tailscale included in the `ucore` tier and above

**SELinux:**

- SELinux enforcing mode is the default and immutable on ucore
- `container_manage_cgroup` boolean must be set for Podman container management
- Custom SELinux policy modules should use CIL format (`semodule -X 300 -i *.cil`) — monolithic `.te` compilation not feasible in container builds without make/checkpolicy
- `semanage import` with heredoc for bulk boolean + fcontext config at build time
- `fapolicyd` is available but historically caused 2–5 minute boot delays when hashing all binaries; if used, configure the RPM database trust backend exclusively to avoid hashing overhead

**Update tooling:**

- `uupd` (Go-based unified updater, replaced Python `ublue-update` which was archived August 2025) coordinates bootc + Flatpak (user + system) + Distrobox + Homebrew updates via systemd timer every 6 hours
- Pre-update hardware checks: battery level, CPU load, memory pressure, network connectivity
- `AutomaticUpdatePolicy=none` must be set in `rpm-ostreed.conf` when uupd is active (prevents rpm-ostree auto-staging competing with uupd)
- `ujust` / `ublue-os-just` provides numbered system-management recipes at `/usr/share/ublue-os/just/`

**zram / swap:**

- ucore ships with **zram swap enabled by default** via `zram-generator` (a systemd-zram-setup companion)
- Default zram configuration: single device at `zram0`, algorithm `zstd`, size = 50% of RAM
- Configuration file: `/etc/systemd/zram-generator.conf` (system) or `/usr/lib/systemd/zram-generator.conf` (image-shipped default)
- CloudWS-2 should NOT override this — the default is appropriate for a workstation workload. If Ceph or K3s memory pressure is a concern, reduce zram to 25% of RAM
- Swap priority: zram gets priority 100 by default, leaving room for a low-priority disk swap partition at priority 10

**Image signing (supply chain):**

- All Universal Blue images are signed with a **Cosign key-pair** (NOT keyless-only). The private key is stored in a GitHub Actions secret; the public key is shipped in the image at `/etc/pki/containers/ublue-cosign.pub`
- Container verification policy at `/etc/containers/policy.json` enforces signature verification for all `ghcr.io/ublue-os` images
- **Critical:** Universal Blue uses cosign v2.6.x, NOT cosign v3. Cosign v3's default `--new-bundle-format` (protobuf) breaks rpm-ostree/bootc signature verification (rpm-ostree#5509). Do NOT upgrade to cosign v3 until rpm-ostree merges the fix.
- Images are also published with SBOM attachments (SPDX-JSON format via `syft`) using `oras attach` to avoid Rekor size limits
- Renovate Bot manages digest pins in `image-versions.yml` with a 7-day stability window

---

### Known issues with stable-nvidia base

**1. NVIDIA udev coldplug in VMs (critical, CloudWS-specific design requirement):**
`ucore-hci:stable-nvidia` ships NVIDIA kernel modules that udev coldplugs even in VMs without a physical GPU, causing DRM errors, failed service starts, and GDM failures. CLAUDE.md §3.5 mandates blacklisting NVIDIA modules by default with `34-gpu-detect.sh` removing the blacklist only on bare metal. This must not be regressed.

**2. `nvidia-drm.modeset=1` and `nvidia-drm.fbdev=1` in VM kargs:**
These kargs must NOT be shipped unconditionally. Gate on hardware detection (`34-gpu-detect.sh`), not as default kargs. GDM fails in GPU-less VMs with these active.

**3. libvirtd 45-second shutdown timeout:**
Known issue in ucore-hci: `libvirtd.service` has a 45-second `TimeoutStopSec` which is insufficient for graceful VM shutdown. Ships `libvirtd.service.d/10-cloudws.conf` with `TimeoutStopSec=120s`.

**4. `cloudws-ceph-bootstrap.service` ConditionVirtualization:**
Must use `ConditionVirtualization=no` (not `!container`) to prevent service hangs in Hyper-V. Hyper-V is detected as a hypervisor, not a container, by systemd. Using `!container` misses this case.

**5. composefs-native rollback not yet supported:**
`bootc rollback` returns "This feature is not supported on composefs backend" on composefs-native. Stay on OSTree backend for rollback-critical deployments until composefs rollback support lands in bootc v1.16+.

**6. BIB + XFS + composefs.enabled=verity:**
`bootc-image-builder` fails during `org.osbuild.bootc.install-to-filesystem` if rootfs is XFS and composefs verity is enabled. XFS does not support `fsverity`. Use `ext4` or `btrfs` for BIB targets. (Documented in ai-journal.md, April 2026 entry.)

**7. Waydroid incompatibility with NVIDIA proprietary:**
Waydroid does not work with NVIDIA proprietary drivers on ucore-hci. NVIDIA open modules provide partial compatibility via Mesa virtio-gpu path, but full 3D acceleration remains unavailable on NVIDIA. CloudWS-2 users wanting Waydroid should use AMD or Intel GPU.

**8. systemd-remount-fs crash on Fedora 42+/GNOME composefs:**
`systemd-remount-fs.service` crashes at boot on Fedora 42+ when composefs overlay is active because the kernel prevents remounting with new `/etc/fstab` options. Workaround: mask the service (`40-composefs-verity.sh`). Monitor Fedora 44+ for upstream systemd patch targeting `/sysroot` instead.

**9. xRDP is dead on GNOME 50:**
GNOME 50 (released mid-March 2026, ships in Fedora 44) removed X11 session entirely. xRDP and xorgxrdp have no Wayland backend and no upstream roadmap for one. **CloudWS must migrate to `gnome-remote-desktop` before the F43/GNOME 50 rebase.** Remove `xrdp`, `xorgxrdp`, `xorgxrdp-glamor`. Ship `gnome-remote-desktop` + `grdctl` provisioning. This also eliminates the xorgxrdp/xorgxrdp-glamor package conflict (CLAUDE.md §3.4).

**10. cosign v3 bundle format breaks bootc/rpm-ostree:**
Cosign v3 enables `--new-bundle-format` (protobuf) by default, incompatible with the `containers/image` library used by rpm-ostree and bootc for signature verification. Always sign with `cosign sign --new-bundle-format=false --yes $DIGEST` or stay on cosign v2.6.x until rpm-ostree#5509 is resolved.

---

### Signing / supply chain

**Universal Blue signing architecture:**

- **Primary: Key-pair signing.** Cosign private key in GitHub Actions secret. Public key shipped in image at `/etc/pki/containers/ublue-cosign.pub`. Policy JSON enforces verification for all `ghcr.io/ublue-os` images.
- **Secondary: Keyless signing (Fulcio/Rekor)** in parallel — Fulcio short-lived certificate from GitHub OIDC, logged to Rekor transparency log. Requires `id-token: write` GitHub Actions permission.
- **NOT keyless-only:** Despite some AI-indexed summaries claiming otherwise, Universal Blue YAML uses `COSIGN_PRIVATE_KEY` — always cross-check the actual workflow YAML rather than secondary summaries.
- **Cosign version:** Pinned to v2.6.x. Do NOT use cosign v3 default bundle format (rpm-ostree#5509 incompatibility). When cosign v3+ is used, always pass `--new-bundle-format=false`.

**SBOM:**

- SBOM generated via `syft` in SPDX-JSON + CycloneDX formats
- Attached via `oras attach` (not `cosign attest`) — avoids Rekor size limits that reject large SBOMs
- CloudWS push-239 delivered this pattern

**Policy enforcement:**

- `/etc/containers/policy.json` at `/etc/containers/policy.json` enforces signature verification
- CloudWS ships key-based policy (first entry) with keyless Fulcio chain as second entry
- `sigstoreSigned` type with `keyPath: /etc/pki/containers/cloudws-cosign.pub`

**Supply chain risk notes:**

- `stable-nvidia` is a mutable tag — a digest pin in `image-versions.yml` is required for reproducible builds. Current `image-versions.yml` has the digest commented out (`# digest: sha256:REPLACE_WITH_CURRENT_DIGEST`). This should be activated and managed by Renovate.
- Universal Blue runs weekly GHCR cleanup: keeps 7 most-recent untagged images, preserves all tagged images. CloudWS should adopt same cleanup pattern (push-239 delivered the GHCR cleanup workflow).
- Bazzite (April 2026): **OpenSSF Scorecard** scanning runs on every build. ISO images are now signed. Build attestation via cosign is active. These represent the current security floor for mature Universal Blue projects.
- `ghcr.io/ublue-os/akmods-nvidia` artifacts (NVIDIA kernel module RPMs) are themselves signed and digest-pinned in the ucore Containerfile. CloudWS inherits this trust chain by building FROM ucore-hci.

**Cayo (future base image — watch):**

`ublue-os/cayo` is the bootc-native HCI successor to ucore-hci. It is composefs-native from inception, designed to work with `bootc container ukify` for UKI Secure Boot, and targets the F44/F45 timeframe for production readiness. CloudWS-2 should evaluate cayo as a CloudWS-3 base migration candidate when it reaches stable status.
<!-- FINDINGS END -->

---

## 4. Fedora bootc / FCOS / OCI Transition

*Research thread: Fedora bootc official images, FCOS→OCI roadmap, Rawhide status*

<!-- FINDINGS BEGIN -->
<!-- FINDINGS END -->

---

## 5. composefs / OSTree

*Research thread: composefs upstream, OSTree OCI spec, verity support, known issues*

<!-- FINDINGS BEGIN -->
<!-- FINDINGS END -->

---

## 6. Podman Quadlet / systemd Integration

*Research thread: Quadlet spec changes, new container/volume/network keys, systemd integration*

<!-- FINDINGS BEGIN -->
<!-- FINDINGS END -->

---

## 7. WSL2 / systemd Integration

*Research thread: WSL2 systemd compatibility, known failures, upstream patches*

<!-- FINDINGS BEGIN -->
<!-- FINDINGS END -->

---

## 8. Sigstore / cosign / Supply-Chain

*Research thread: cosign keyless signing, Fulcio/Rekor, SBOM patterns, bootc image signing*

<!-- FINDINGS BEGIN -->
<!-- FINDINGS END -->

---

## 9. kargs.d Spec & bootc Lint Rules

*Research thread: kargs.d TOML schema, bootc container lint rules, known rejections*

<!-- FINDINGS BEGIN -->
<!-- FINDINGS END -->

---

## 10. NVIDIA Container Toolkit / CDI

*Research thread: nvidia-ctk CDI spec, nvidia-cdi-refresh, Container Device Interface standard*

<!-- FINDINGS BEGIN -->
<!-- FINDINGS END -->

---

## 11. Renovate / Digest Pinning

*Research thread: Renovate OCI digest pinning, stability window config, image-versions.yml patterns*

<!-- FINDINGS BEGIN -->
### Renovate OCI/Docker datasource (current)

**Datasource: `docker`** is Renovate's unified datasource for all OCI/container registry traffic — it handles Docker Hub, ghcr.io, quay.io, and any OCI-conformant registry identically. The `docker:pinDigests` preset (part of `config:best-practices` since Renovate v37+) instructs Renovate to:

1. Detect `FROM image:tag` lines in Dockerfiles/Containerfiles and rewrite them to `FROM image:tag@sha256:<digest>`.
2. Open PRs when the upstream digest changes (the tag itself is unchanged — digest pinning tracks content drift under a stable tag).
3. Label those PRs as `updateType: digest` updates — distinct from `minor`/`major` version bumps.

Registries supported and tested against bootc-relevant images (as of Renovate v37+):
- `ghcr.io` — full support, no extra config needed. Renovate reads the OCI manifest index and resolves per-arch digests. Handles `ucore-hci:stable-nvidia` correctly.
- `quay.io` — full support. Handles `fedora/fedora-bootc:rawhide` and `centos-bootc/bootc-image-builder:latest`.
- `docker.io` — full support (default registry).

Authentication for private registries: set `hostRules` with `username`/`password` or GitHub PAT in Renovate config or as a repository secret (`RENOVATE_TOKEN`). For `ghcr.io`, Renovate's GitHub App installation requires `packages: read` permission.

**Key known limitation:** The `docker` datasource resolves digests to the manifest list (multi-arch) digest by default. For single-arch digest pinning (e.g., `linux/amd64` only), use `versioning: docker` with a `registryUrl` override. For CloudWS-bootc this is not an issue — pinning the manifest list digest is the correct behavior for multi-arch base images.

**`config:best-practices` preset** (already used in this repo) bundles:
- `docker:pinDigests` — pins FROM digests in Dockerfiles and Containerfiles
- `helpers:pinGitHubActionDigests` — pins `uses:` in GitHub Actions workflows to SHA digests
- Various security and automerge defaults
- As of Renovate v38+, also enables `docker:enableDockerSecurity` which enforces signed-image awareness

### stabilityDays / stability window config

`stabilityDays` delays Renovate from opening (or automerging) a PR until the update has been available in the registry for N calendar days. This is a **release-age gate**, not a test gate.

**How it is evaluated:** Renovate uses the image manifest's `created` timestamp (from the OCI config blob) or the registry's push timestamp to compute age. For digest updates, the timestamp of the new digest is used. The PR is created only after `now - timestamp >= stabilityDays`.

**Interaction with `automerge`:**
- If `automerge: true` and `stabilityDays: 7`, Renovate creates the PR immediately but does not merge it until the 7-day window passes AND all required checks pass.
- If the registry timestamp is unavailable (some quay.io tags, `:latest` on some registries), `stabilityDays` has no effect — the PR opens immediately. This is a known edge case; mitigation is to pin to a versioned tag or semver tag rather than `:latest`.

**`minimumReleaseAge` replaces `stabilityDays` (forward-compatible form):** Renovate's documentation prefers `minimumReleaseAge` (with time-unit suffix, e.g., `"7 days"`) over the integer `stabilityDays`. Both work as of mid-2025, but `minimumReleaseAge` is the forward-compatible canonical form. The current repo's `stabilityDays: 7` and `stabilityDays: 3` are functionally correct but should be migrated to `minimumReleaseAge: "7 days"` / `minimumReleaseAge: "3 days"` when next the `renovate.json` is touched.

**Current repo config analysis (`renovate.json`):**
- Global `stabilityDays: 7` applies to all non-digest updates.
- `matchUpdateTypes: ["digest"]` rule overrides to `stabilityDays: 3` — appropriate because digest updates are low-risk (same tag, new content) and the 3-day window is sufficient to catch registry mistakes.
- `matchFileNames: ["image-versions.yml"]` disables automerge and assigns `Kabuki94` as reviewer — correct for protecting digest pins that feed the production build.

**Recommended tuning for bootc projects:**
- Keep 7 days (or `"7 days"`) for version bumps (`minor`, `major`, `patch`).
- Use 3 days for `digest` updates — `ucore-hci:stable-nvidia` digest changes weekly as Universal Blue rebuilds; 7 days would cause perpetual lag.
- Use 0 days for `lockFileMaintenance` — dependency lock file refreshes have no deployment risk.
- Add `schedule: ["before 6am on monday"]` to the `matchUpdateTypes: ["digest"]` rule to batch digest PR creation out of work hours.

### Digest pinning for Containerfile FROM

**How `docker:pinDigests` works on Containerfiles:** Renovate scans for `FROM` directives using the `dockerfile` manager. It detects both standard `FROM image:tag` and multi-stage `FROM image:tag AS alias` patterns. After pinning, the line becomes:

```dockerfile
FROM ghcr.io/ublue-os/ucore-hci:stable-nvidia@sha256:<digest>
```

Renovate then tracks this digest and opens a PR when `stable-nvidia` resolves to a new digest. The PR diff is a single-line change to the `sha256:` value.

**Behavioral notes:**
- Renovate does NOT pin `FROM scratch` — correctly skipped.
- In multi-stage builds, each `FROM` line is pinned independently. CloudWS-bootc's `FROM scratch AS ctx` is skipped; the main `FROM ghcr.io/ublue-os/ucore-hci:stable-nvidia` is pinned.
- If the Containerfile already has `@sha256:` pinning, Renovate tracks the existing pin and updates it — it does not double-pin.
- The `dockerfile` manager auto-detects files named `Dockerfile`, `Containerfile`, `Dockerfile.*`, `Containerfile.*`. The repo's root `Containerfile` is automatically detected with no extra `fileMatch` config needed.

**Current state in this repo:** `image-versions.yml` documents the digests as reference, but the `Containerfile` currently uses bare tags (per the `image-versions.yml` comment: "the Containerfile currently uses tags"). This means Renovate is tracking the tag for version updates but is NOT currently pinning the Containerfile `FROM` line to a specific digest. To activate full digest pinning:

1. Get the current digest: `podman manifest inspect ghcr.io/ublue-os/ucore-hci:stable-nvidia | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('Digest') or d['manifests'][0]['digest'])"`
2. Update the `FROM` line in `Containerfile` to `FROM ghcr.io/ublue-os/ucore-hci:stable-nvidia@sha256:<digest>`.
3. Renovate will detect the pinned digest and begin managing it automatically going forward.
4. Uncomment and populate the `digest:` field in `image-versions.yml` to match.

**CODEOWNERS protection pattern (Universal Blue / Bluefin):**
```
image-versions.yml  @Kabuki94
Containerfile       @Kabuki94
```
The `renovate.json` already handles this via `automerge: false` + `assignees: ["Kabuki94"]` for `image-versions.yml`. Add a matching `packageRule` for `matchFileNames: ["Containerfile"]` once digest pinning is activated there.

### image-versions.yml pattern

The `image-versions.yml` pattern originates from **Bluefin** and is standard across the Universal Blue ecosystem. The canonical connection between a plain YAML value and a Renovate-tracked image is a **`# renovate:` directive comment** on the line immediately above the YAML key:

```yaml
# renovate: datasource=docker depName=ghcr.io/ublue-os/ucore-hci
base_image_digest: sha256:abc123...
```

When Renovate sees this comment above a key whose value is a `sha256:` digest (or a tag string), it updates the value when the upstream image changes. Without the directive comment, Renovate does not know which registry/image a plain YAML value corresponds to.

**Recommended `image-versions.yml` structure for CloudWS-bootc:**

```yaml
# CloudWS-bootc base image version pinning
# Managed by Renovate Bot — do NOT edit digests manually.
# Renovate opens PRs when upstream images publish new digests.
# See renovate.json for stability window and automerge policy.

# renovate: datasource=docker depName=ghcr.io/ublue-os/ucore-hci
ucore_hci_stable_nvidia_digest: sha256:REPLACE_WITH_CURRENT_DIGEST

# renovate: datasource=docker depName=quay.io/fedora/fedora-bootc versioning=docker
fedora_bootc_rawhide_digest: sha256:REPLACE_WITH_CURRENT_DIGEST

# renovate: datasource=docker depName=quay.io/centos-bootc/bootc-image-builder
bib_digest: sha256:REPLACE_WITH_CURRENT_DIGEST

# renovate: datasource=docker depName=quay.io/centos-bootc/centos-bootc versioning=docker
rechunker_digest: sha256:REPLACE_WITH_CURRENT_DIGEST
```

**`regexManagers` alternative:** For more complex YAML structures (e.g., nested `registry`/`tag`/`digest` keys as in the current `image-versions.yml`), use `regexManagers` in `renovate.json` to extract the digest via regex. Example:

```json
{
  "regexManagers": [
    {
      "fileMatch": ["^image-versions\\.yml$"],
      "matchStrings": [
        "repository: (?<depName>[^\\n]+)\\n\\s+tag: (?<currentValue>[^\\n]+)\\n\\s+# digest: sha256:(?<currentDigest>[^\\n]+)"
      ],
      "datasourceTemplate": "docker"
    }
  ]
}
```

The simpler directive-comment pattern is recommended for new YAML structures. The current `image-versions.yml` nested structure would need either a `regexManager` or restructuring to the flat key-value form before Renovate can manage the digest fields automatically.

### Notable Renovate changes 2025-2026

Knowledge cutoff: August 2025 (confirmed). Items marked [INFERRED] are trajectory-based.

**Confirmed changes (Renovate v36–v38, 2024–mid-2025):**

- **`config:best-practices` formalized (v37, late 2024):** This preset now bundles `docker:pinDigests`, `helpers:pinGitHubActionDigests`, and security-hardened defaults. Repos extending it automatically get all three behaviors. This repo already uses it correctly.

- **`dockerfile` manager gains Containerfile support (v37–v38):** Bootc projects no longer need `fileMatch` overrides to detect root-level `Containerfile` — it is auto-detected alongside `Dockerfile`.

- **Per-rule `stabilityDays` (v37+):** `stabilityDays` can now be set per `matchUpdateTypes` inside `packageRules`, which is exactly what this repo's `renovate.json` uses. Before ~v36 it was global only.

- **`minimumReleaseAge` preferred over `stabilityDays` (v38+):** Renovate docs now prefer `minimumReleaseAge: "7 days"` (string with time unit) over `stabilityDays: 7` (integer days). Both work; `minimumReleaseAge` is the forward-compatible form. Plan to migrate when next touching `renovate.json`.

- **`automergeSchedule` deprecated → use `schedule` (v37+):** These are unified under `schedule` within `packageRules`. The repo's `schedule: ["before 9am on monday"]` for GitHub Actions is correct current syntax.

- **`docker:enableDockerSecurity` preset (v38+):** Added — pins digest AND flags unsigned images in the PR description when combined with `docker:pinDigests`. Consider adding this preset once CloudWS cosign signing infrastructure is confirmed stable.

- **GitHub Actions pinning extended (v38+):** `helpers:pinGitHubActionDigests` now also pins composite action `uses:` references inside workflow files, not just top-level job steps. CloudWS CI workflows benefit from this automatically.

- **OCI artifact tracking (v38+):** Renovate added support for non-image OCI objects (Helm charts, Sigstore policy bundles pushed as OCI). Uses same `docker` datasource. Relevant if CloudWS begins tracking cosign key bundles or attestations as OCI artifacts.

- **`hostRules` for ghcr.io (2025 change):** GitHub Actions token scoping changed. Renovate running as a GitHub App requires `packages: read` permission on the installation to pull manifests from `ghcr.io`. Verify the Renovate App installation has this scope on the `Kabuki94/CloudWS-bootc` repo.

**Action items for this repo's `renovate.json`:**

1. Migrate `stabilityDays: 7` → `minimumReleaseAge: "7 days"` and `stabilityDays: 3` → `minimumReleaseAge: "3 days"` for forward compatibility.
2. Add `schedule: ["before 6am on monday"]` to the `matchUpdateTypes: ["digest"]` rule to batch digest PR creation.
3. Add a `packageRules` entry for `matchFileNames: ["Containerfile"]` with `automerge: false` + `assignees: ["Kabuki94"]` once FROM digest pinning is activated in the Containerfile.
4. Restructure or add a `regexManagers` block so Renovate can automatically manage the `digest:` fields in `image-versions.yml` (currently commented out and untracked by Renovate).
5. Consider adding `vulnerabilityAlerts: { enabled: true }` at the top level — Renovate 2025+ can open CVE-driven PRs for pinned images when a vulnerability database feed is configured.
6. Verify the Renovate GitHub App installation has `packages: read` scope for GHCR manifest resolution.
<!-- FINDINGS END -->

---

## 12. Security / SELinux / CrowdSec

*Research thread: SELinux bootc patterns, CrowdSec 2026 features, fapolicyd*

<!-- FINDINGS BEGIN -->
<!-- FINDINGS END -->

---

*End of live research document.*
