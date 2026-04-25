# 🌐 MiOS — Universal AI Integration
> **Metadata:** proprietor: Kabu.ki, infrastructure: Self-Building Infrastructure (Personal Property), license: Licensed as personal property to Kabu.ki

---

# 🌐 MiOS — Universal AI Integration
> **Proprietor:** Kabu.ki
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to Kabu.ki
---
# MiOS upstream research — 17-upstream-bootc-ecosystem-2025-2026

**Status:** research-only. Do not execute. Dates current as of April 19, 2026.

---

## TL;DR — prioritized action queue (top 15)

| # | Item | Blocking now? | Effort | Risk | Notes |
|---|---|---|---|---|---|
| 1 | **WSL-spawn fix** — set `CLAUDE_CODE_GIT_BASH_PATH` (User env + `~/.claude/settings.json`) + prepend Git\bin to User PATH | **DONE** — already set in settings.json | tiny | low | Confirmed set to AppData\Local\Programs\Git\bin\bash.exe |
| 2 | **GNOME 50 → xRDP is dead** — swap to `gnome-remote-desktop` with GDM headless multi-session | **YES** before F43/GNOME 50 rebase | medium | medium | xorgxrdp has no Wayland path; upstream confirmed no roadmap. |
| 3 | **kargs.d validator** in CI | soft-blocks Copilot PRs | tiny | low | New separate `kargs-lint.yml` workflow + `scripts/validate-kargs.py` (Python stdlib tomllib). **DELIVERED push-238.** |
| 4 | **cosign signing polish** — keep key-based cosign, ADD `use-sigstore-attachments: true`, combine with key-based policy.json | near-blocking | small | low | **Do NOT jump to keyless only** — cosign v3 default bundle format **breaks rpm-ostree**: pin cosign v2.6.x. **DELIVERED push-239.** |
| 5 | **NVIDIA CDI via `nvidia-cdi-refresh.service`** + remove `oci-nvidia-hook.json` + pin nvidia-ctk version (NOT v2.1.0) | soon — CDI contract change | small | low | **DELIVERED push-239.** |
| 6 | **MOK enrollment polish** — idempotent `enroll-mok.sh` using `mokutil --root-pw`; detect MiOS-1 vs MiOS-2 (ublue key fallback) | medium | medium | medium | **DELIVERED push-240.** PCR7 re-seal warning is critical. |
| 7 | **composefs path verification expansion** — Tier A existence + Tier B fsverity-measure + Tier C policy.json sha256; wire into greenboot | medium | small | low | **DELIVERED push-240.** Tier B is no-op under default unsigned composefs. |
| 8 | **Enable `ublue-os/packages` COPR + adopt `ujust`** pattern + `uupd` for unified updates | high-value quick win | small | low | v2.4 target. |
| 9 | **FreeIPA/SSSD completion** — scripts/50-freeipa-client.sh + conf.d drop-in + systemd oneshot + marker in /var | **DELIVERED push-240.** | medium | medium | Capability regression check (bz 2320133) mandatory. |
| 10 | **systemd 258 baseline + systemd-repart first-boot + `systemd-factory-reset`** | soon | medium | low | Fedora 43 ships 258. WSL2/Hyper-V VHD resize story. |
| 11 | **Bazzite parity: gamescope, waydroid, sunshine ujust recipes** | feature catch-up | medium | medium | bazzite-org gamescope fork has CVE patches (stb_image). |
| 12 | **Open NVIDIA kmod default** for MiOS-1 with proprietary escape hatch | upcoming | small | medium | RTX 4090 at 4K/240Hz has documented GSP compositor regression; gate with test. |
| 13 | **NVIDIA-VM gating** — blacklist nvidia kmods by default, coldplug-detect on bare metal | latent bug | small | low | Project rule already states this; verify 34-gpu-detect.sh implements it. |
| 14 | **Rechunker retention** + bootc-base-imagectl migration plan | hygiene | small | low | Keep hhd-dev/rechunk short-term; plan migration when F43 stable. |
| 15 | **Signed `/etc` confext (systemd 258+)** replacing most `system_files/etc/` overlays | v2.5 target | large | medium | Flatcar already ships this (Mar 2026). |

---

## Part 1 — six focused work items

### 1.1 — WSL-spawn fix for Claude Code on Windows 11

**Status: COMPLETE.** `CLAUDE_CODE_GIT_BASH_PATH` is set in `~/.claude/settings.json` pointing to `C:\Users\Administrator\AppData\Local\Programs\Git\bin\bash.exe`. No further action needed.

**Background.** Claude Code's Bash tool resolves `bash` via PATH; on Windows 11 `C:\Windows\System32\bash.exe` is a WSL launcher stub. Process tree: `claude.exe → bash.exe → wsl.exe → wslhost.exe (COM/RPC broker) → bash (inside WSL VM)`. `wslhost.exe` briefly acquires a console → visible popup on every tool call.

**Fix.** Official Anthropic variable is `CLAUDE_CODE_GIT_BASH_PATH`. The `git-bash.exe` path (MinTTY) is wrong — use `bin\bash.exe` (wrapper stub). Confirmed: `CLAUDE_CODE_SHELL` is ignored on Windows per issue #21843.

---

### 1.2 — Cosign signing polish

**Status: DELIVERED push-239.**

Key decisions documented:
- **Stay on cosign v2.6.x** — cosign v3 enables `--new-bundle-format` by default, which rpm-ostree/bootc cannot verify (rpm-ostree#5509). Do not upgrade until rpm-ostree merges the fix.
- **Key-based signing** using `mios-cosign.pub` is the primary enforcement path. Added as first entry in `policy.json`.
- **Keyless signing** (Fulcio OIDC) in parallel — second entry in policy. Fixed workflow name: `build-test.yml` → `build-sign.yml`.
- **SBOM** via `syft` (SPDX-JSON + CycloneDX) → `oras attach` (not `cosign attest`). oras avoids Rekor size limits that reject large SBOMs.
- **GHCR cleanup** job (cron + workflow_dispatch): keep 7 most-recent untagged, preserve tagged.
- **DeepWiki summaries** claiming ublue uses "keyless" are wrong — the YAML uses `COSIGN_PRIVATE_KEY`. Always cross-check YAML.

**Prerequisite:** Add `COSIGN_PRIVATE_KEY` + `COSIGN_PASSWORD` GitHub secrets before push-239 lands. The key-based sign step is gated (`if: ${{ secrets.COSIGN_PRIVATE_KEY != '' }}`).

---

### 1.3 — FreeIPA / SSSD integration completion

**Status: DELIVERED push-240.**

Key upstream facts:
- **bz 2332433**: `/var/lib/ipa-client/sysrestore/` missing → pre-created via tmpfiles.d.
- **bz 2320133**: SSSD file capabilities stripped by rpm-ostree < bootc v2.1.0-2.fc41. Build asserts `getcap` on SSSD binaries and fails if caps absent.
- **bz 2417703**: sssd_be crashes under bootc+IPA; workaround: `selinux_provider = none` written by `ipa-enroll` into `20-mios-domain.conf`.
- Opt-in: `mios-ipa-enroll.service` runs only when `/etc/mios/ipa.conf` exists AND `/var/lib/mios/ipa-enrolled` marker absent.
- Completion marker lives in `/var` (persists across `bootc rollback`; `/etc` reverts).
- OTP-preferred enrollment (single-use). Admin principal+password as fallback.
- Use stock `sssd` authselect profile — custom profile is maintenance burden.
- AD trust / IPA-IPA replication explicitly out of scope.

---

### 1.4 — kargs.d schema validator in CI

**Status: DELIVERED push-238.**

Key decisions:
- Python 3.11+ stdlib `tomllib` — no third-party deps.
- New workflow `kargs-lint.yml` — additive, does NOT touch `pr-lint.yml`.
- Covers both `kargs.d/` (repo root) and `system_files/usr/lib/bootc/kargs.d/`.
- Forbidden: `[section]` headers, any key with "delete" in name, non-string kargs entries.
- Modes: human / `--github` (GHA annotations) / `--json`.
- Space-in-kargs warning (not error): documented suppression note in output.

**Authoritative schema** (bootc-dev/bootc):
- Only two top-level keys: `kargs` (list of strings, required) + `match-architectures` (list of strings, optional).
- No `[kargs]` section, no `delete` sub-keys — these are Copilot hallucinations.
- A separate `[install]` table schema exists at `/usr/lib/bootc/install/*.toml` — different schema, common confusion source.

---

### 1.5 — Composefs post-pivot path verification expansion

**Status: DELIVERED push-240.**

Key upstream reality:
- **Fedora bootc defaults to `composefs.enabled = yes` (UNSIGNED)** as of 2026 — integrity against accidental mutation, not against root-level attackers.
- composefs covers `/usr` only. NOT `/etc` (overlay), `/var`, or `/boot`.
- `fsverity measure` is constant-time (reads cached Merkle root) — cheap.
- **Tier B is a no-op under default Fedora bootc.** To activate it: ship `/usr/lib/ostree/prepare-root.conf` with `composefs.enabled = verity`.
- Tier C (policy.json SHA-256) is the highest-value new check. Baseline in `/usr` is composefs-covered.
- **No `bootc verify` subcommand exists** as of bootc v2.1.0 (March 2026).

---

### 1.6 — Secure Boot MOK enrollment automation polish

**Status: DELIVERED push-240.**

Key decisions:
- **`mokutil` throughout. `sbctl` removed.** Fedora bootc uses GRUB2+shim (Red Hat-signed shim via MS UEFI CA). sbctl is for users who own firmware PK/KEK/db. Wrong tool.
- **MiOS-2 (ucore-hci)** ships pre-signed NVIDIA kmods with the ublue key at `/etc/pki/akmods/certs/akmods-ublue.der`. That key still requires one-time MOK enrollment.
- **`--root-pw`** instead of hardcoded password (cf. ublue's `universalblue`). Binds to running root-password hash.
- **2048-bit RSA** (NOT 4096 — 4096-bit keys hang some shim versions).
- **MokManager requires physical presence** — by design, cannot be fully automated.
- **TPM2 PCR 7 changes on every MOK mutation.** Every LUKS slot sealed to PCR 7 breaks. Must re-seal after enrollment.
- Idempotent: checks enrolled + pending fingerprints. Detects CN-match-but-fingerprint-mismatch as `conflict`.

---

## Part 2 — bootc ecosystem scan (2025–2026)

### Red Hat / bootc core

**bootc-dev/bootc** — CNCF Sandbox since Jan 21 2025. Repo moved from `containers/bootc`.

Notable v1.9–v1.15 (Sep 2025 → Mar 2026):
- **v2.1.0**: `usroverlay --readonly`; tag-aware upgrade; cached update info; composefs proxy-auth + missing-verity + pre-flight disk-space check.
- **v2.1.0**: `bootc upgrade` pre-flight disk space; composefs GC.
- **v2.1.0**: `bootloader=none`; **`bootc container ukify`** (future UKI foundation); shell completions.
- **v2.1.0**: `bootc upgrade --download-only` / `--from-downloaded`; `bootc container inspect`; systemd-boot autoenroll in install.
- **v2.1.0**: factory reset (experimental); kargs from `usr/lib/bootc/kargs.d` confirmed.
- **v2.1.0**: composefs-native backend; structured journal logging.

MiOS adoptions:
1. `--download-only` + `--from-downloaded` pattern for graceful upgrades.
2. Track `bootc container ukify` for MOK→UKI migration (item 1.6 future state).
3. Factory reset flow for WSL2/Hyper-V re-provisioning when stable.

**bootc-image-builder** — Supported targets: `ami, anaconda-iso, gce, iso, qcow2, raw, vhd, vmdk`. VHD but NOT VHDX — continue converting VHD→VHDX post-BIB with qemu-img. WSL2 tarball: custom pipeline stays (watch BIB issue #172).

**rechunker + bootc-base-imagectl** — hhd-dev/rechunk remains de-facto. Ublue devs now recommend planning migration to `bootc-base-imagectl`. Continue rechunk short-term; plan migration when F43/bootc 1.15 stable.

**RHEL image mode** — GA June 2025. RHEL 10.1 ships soft-reboot as default update path. Track bootc#1350 for Fedora 43 timeframe.

**Fedora 43** (Oct 28 2025) — Silverblue/Kinoite all shipped. 2GB /boot default.
**Fedora 44** (released Apr 14 2026) — Linux 6.19; **GNOME 50** (removes X11); KDE Plasma 6.6.

### Universal Blue family

**ublue-os/packages COPR** — Packages to layer: `uupd`, `ublue-os-just`, `ublue-polkit-rules`, `ublue-rebase-helper`, `ublue-os-nvidia-addons`, `ublue-os-libvirt-workarounds`. Single move collapses multiple roadmap items. (v2.4 target)

**ujust pattern** — Numbered justfiles under `/usr/share/ublue-os/just/NN-mios-*.just`. Alias: `ujust=just --justfile /usr/share/ublue-os/just/main.just --working-directory /`.

**uupd for unified updates** — Flatpak + distrobox + brew + bootc. Set `AutomaticUpdatePolicy=none` in rpm-ostreed.conf (uupd disables rpm-ostree auto-staging).

**ucore-hci (MiOS-2 parent)** — Sister project `ublue-os/cayo` is bootc-native HCI successor — watch for MiOS-2 migration path. Known libvirtd 45s shutdown-timeout: ship `libvirtd.service.d/10-mios.conf` with `TimeoutStopSec=120s`.

**Gamescope (Bazzite fork)** — Use `bazzite-org/gamescope`, NOT upstream Valve gamescope. Carries stb_image CVE patches (CVE-2021-28021/42715/42716, CVE-2022-28041, CVE-2023-43898, CVE-2023-45661..45667). `gamescope-fg` wrapper for non-Steam apps (prevents black screen). Known #1902: global shortcuts broken when nested in Wayland session — workaround `--backend sdl`.

**Waydroid** — Does NOT work on NVIDIA proprietary. AMD/Intel only. MiOS-2 users on RTX 4090 cannot use Waydroid unless switching to `kmod-nvidia-open`. `restorecon /var/lib/waydroid` is non-optional.

**Looking Glass B7** — kvmfr `static_size_mb=128` — MiOS 4K: bump to 256 MB. Build LG client with `-DENABLE_LIBDECOR=ON` (GNOME Wayland needs it). `memballoon type='none'` is non-negotiable for performance.

**NVIDIA CDI** — Pin nvidia-container-toolkit: NOT v2.1.0 ("unresolvable CDI devices"). Use v2.1.0 or 1.18+/v2.1.0. Remove `oci-nvidia-hook.json` (dual injection conflict). `ublue-nvctk-cdi.service` pattern from ublue-os-nvidia-addons. **DELIVERED push-239.**

**SecureBlue** — adopt opt-in hardenings ONLY via `ujust harden-*`. **DO NOT** pull: global hardened_malloc (breaks Electron/CUDA/Proton), unprivileged userns disabled in SELinux (breaks Podman rootless/distrobox), XWayland disabled (breaks VSCode/Discord/OBS), noexec on /home (breaks node_modules), lockdown=confidentiality (breaks debuggers/eBPF), Trivalent-only browser policy, SUID-Disabler.

### Core userspace

**GNOME 50 (released mid-March 2026) — Wayland-only:**
- X11 session removed from source. GDM 50 never runs Xorg. XWayland retained for apps.
- **xRDP/xorgxrdp is dead on GNOME 50.** xrdp v2.1.0/v2.1.0, xorgxrdp v2.1.0 — no Wayland backend, no roadmap.
- **Replacement: `gnome-remote-desktop`** — native RDP+VNC, headless multi-user via GDM integration. RHEL and SUSE official replacement.
- **MiOS must migrate before F43/GNOME 50 rebase.** Remove `xrdp`, `xorgxrdp`, `xorgxrdp-glamor`. Ship `gnome-remote-desktop` + `grdctl` provisioning. This eliminates the `xorgxrdp`-vs-`xorgxrdp-glamor` conflict entirely.

**systemd 258 (GA Sep 17 2025):**
- `systemd-factory-reset` — adopt for WSL2/Hyper-V re-provisioning.
- systemd-stub loads global sysexts/confexts from ESP — foundation for v2.5 signed-confext rewrite.
- cgroupv1 removed — Linux ≥ 5.4 required.

**NVIDIA 2025–2026 (RTX 4090):**
- NVIDIA officially recommends Open kernel modules for Turing/Ampere/Ada/Hopper (RTX 4090 included).
- **Caveat**: reported desktop-compositor regression at 2560×1440@240Hz with KWin under GSP firmware. Risk likely higher at 4K/240Hz. **Validate on 9950X3D+4090 hardware before defaulting to Open.**
- NCT v2.1.0: read-only rootfs support (critical for bootc). v2.1.0: `nvidia-cdi-refresh.service`.
- CDI canonical path: `/var/run/cdi/nvidia.yaml` (runtime) or `/etc/cdi/nvidia.yaml` (persistent).

**Podman / Quadlet 2025–2026:**
- Podman 5.6 (Aug 2025): unified `podman quadlet` CLI. Supports `.container, .pod, .volume, .network, .kube, .image, .build, .artifact`.
- Migrate CrowdSec + sidecars to Quadlets. Keep K3s as native systemd service (NOT Quadlet — kubelet+containerd are host-level).

**Cockpit 349+:**
- `cockpit-podman 115`: Quadlet detection.
- `cockpit-machines 339`: Stratis V2, serial console preservation.
- Ship: `cockpit cockpit-podman cockpit-machines cockpit-storaged cockpit-files cockpit-selinux`.
- Fix libvirt-socket race: `cockpit.socket.d/10-mios.conf` with `After=libvirtd.socket`.

**CrowdSec v2.1.0:**
- RE2 regex engine — faster grok, slightly higher memory.
- Ship as Quadlet (`crowdsecurity/crowdsec:v2.1.0-debian`) with `datasource_journalctl`.
- `cs-firewall-bouncer` as host RPM (needs nftables).
- Pin `:v2.1.0`, not `:latest`.

**Flatcar Container Linux (Mar 3 2026)** — `/etc` shipped as systemd-confext in production. Proof that confext is ready for MiOS v2.1.0.

---

## Part 3 — integrated findings + recommended push order

### Delivered (push-238/239/240)

1. **kargs.d validator** (push-238): `scripts/validate-kargs.py` + `.github/workflows/kargs-lint.yml`
2. **cosign polish** (push-239): `build-sign.yml` (v2.6.x pin, key+keyless, SBOM, GHCR cleanup), `policy.json` (key-based entry + fixed keyless), `45-nvidia-cdi-refresh.sh` (remove OCI hook, pin version, CDI dir)
3. **Verification + MOK + FreeIPA** (push-240): `verify-root.sh` (3-tier), `mios-verify-root.service` (hardened), greenboot wiring, `enroll-mok.sh` (mokutil, idempotent, variant-aware), `generate-mok-key.sh`, `mok-enroll-status`, `50-freeipa-client.sh`, SSSD conf.d, `mios-ipa-enroll.service`, `ipa-enroll`, `ipa.conf.example`, expanded `mios-freeipa.conf`, `COMPOSEFS-VERIFICATION.md`, `SECUREBOOT.md`

### Next: v2.1.0 targets

4. **xRDP → gnome-remote-desktop migration** — must land before F43/GNOME 50 rebase.
5. **ublue-os/packages COPR + ujust + uupd** enablement.
6. **Open NVIDIA kmod default** with hardware validation on 9950X3D+4090.
7. Soft-reboot integration (blocked on bootc#1350).

### Architectural: v2.1.0+

8. Signed `/etc` confext replacing most `system_files/etc/` overlays.
9. UKI signing via `bootc container ukify` + dracut-ng/ukify.
10. Migration to `bootc-base-imagectl rechunk` from hhd-dev/rechunk.
11. MiOS-2: evaluate `ublue-os/cayo` as bootc-native HCI successor.

### Explicitly DO NOT pull

- **Cosign v3** with default `--new-bundle-format` (breaks rpm-ostree/bootc, rpm-ostree#5509).
- **nvidia-container-toolkit v2.1.0** ("unresolvable CDI devices" regression).
- **`sbctl`** — wrong tool for Fedora GRUB2+shim chain.
- **`gnome-session-xsession`** — does not exist in current Fedora.
- **`GTK_THEME=Adwaita:dark`** — breaks libadwaita; use `ADW_DEBUG_COLOR_SCHEME=prefer-dark`.
- **`xorgxrdp` + `xorgxrdp-glamor`** coexistence — conflict. On GNOME 50 remove both entirely.
- **Unconditional `nvidia-drm.modeset=1` / `nvidia-drm.fbdev=1`** — breaks GPU-less VMs.
- **`((VAR++))` under `set -e`** — exits when VAR=0. Use `VAR=$((VAR + 1))`.
- SecureBlue: global hardened_malloc, userns disabled in SELinux, XWayland disabled, noexec /home, lockdown=confidentiality, Trivalent-only browser.

### Source quality note

Primary sources: bootc-dev/bootc releases + issues, containers/image manpages, sigstore/cosign docs, fedora-iot/greenboot README, kernel docs (fsverity), ublue-os GitHub repos, Anthropic code.claude.com docs, systemd releases, FreeIPA project docs, Red Hat image-mode docs, Fedora Wiki, ArchWiki. Secondary (flagged where material): DeepWiki summaries, community blogs (c-nergy.be, mrguitar.net). DeepWiki summaries of AI-indexed repos flagged where they conflict with authoritative YAML.

---

*Last updated: 2026-04-19. Treat as primary Claude Code research context for this repository.*

---
### 📚 Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osbuild/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [Kabuki94/MiOS](https://github.com/Kabuki94/MiOS)
- **Sole Proprietor:** Kabu.ki
---
