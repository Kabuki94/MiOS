# CloudWS-bootc upstream research — 17-upstream-bootc-ecosystem-2025-2026

**Status:** research-only. Do not execute. Dates current as of April 19, 2026.

---

## TL;DR — prioritized action queue (top 15)

| # | Item | Blocking now? | Effort | Risk | Notes |
|---|---|---|---|---|---|
| 1 | **1.1 WSL-spawn fix** — set `CLAUDE_CODE_GIT_BASH_PATH` (User env + `~/.claude/settings.json`) + prepend `C:\Program Files\Git\bin` to User PATH | **YES — blocks every tool call** | tiny | low | Anthropic-documented variable. Standalone one-shot PS7 script, not a push. |
| 2 | **GNOME 50 → xRDP is dead** — swap to `gnome-remote-desktop` with GDM headless multi-session | **YES** before F43/GNOME 50 rebase | medium | medium | xorgxrdp has no Wayland path; upstream confirmed no roadmap. |
| 3 | **1.4 kargs.d validator** in CI | soft-blocks Copilot PRs | tiny | low | New separate `kargs-lint.yml` workflow + `scripts/validate-kargs.py` (Python stdlib tomllib). |
| 4 | **1.2 cosign signing polish** — keep key-based cosign, ADD `use-sigstore-attachments: true`, combine with key-based policy.json | near-blocking | small | low | **Do NOT jump to keyless yet** — containers/image still immature; ublue explicitly deferred. Cosign v3 default bundle format **breaks rpm-ostree**: pin cosign v2 or pass `--new-bundle-format=false`. |
| 5 | **NVIDIA CDI via `nvidia-cdi-refresh.service`** + remove `oci-nvidia-hook.json` + pin nvidia-ctk version (NOT 1.17.8) | soon — CDI contract change | small | low | Adopt ublue `ublue-nvctk-cdi.service` + nvidia-container SELinux module via `ublue-os-nvidia-addons`. |
| 6 | **1.6 MOK enrollment polish** — idempotent `enroll-mok.sh` using `mokutil --root-pw`; detect CloudWS-1 vs CloudWS-2 (ublue key fallback) | medium | medium | medium | PCR7 re-seal warning is the single most underdocumented gotcha. |
| 7 | **1.5 composefs path verification expansion** — Tier A existence + Tier B fsverity-measure + Tier C policy.json sha256; wire into greenboot | medium | small | low | Greenboot rollback on fail. Tier B is no-op under default unsigned composefs — call that out in docs. |
| 8 | **Enable `ublue-os/packages` COPR + adopt `ujust`** pattern (numbered `/usr/share/ublue-os/just/*.just`) + `uupd` for unified updates | high-value quick win | small | low | Reuses `ublue-polkit-rules`, `ublue-rebase-helper`, `ublue-os-just`, `ublue-os-libvirt-workarounds`, `ublue-os-nvidia-addons`. |
| 9 | **1.3 FreeIPA/SSSD completion** — scripts/40-freeipa-client.sh + conf.d drop-in + systemd oneshot + marker in /var | optional feature | medium | medium | Capability regression check is mandatory (bz 2320133). |
| 10 | **systemd 258 baseline + systemd-repart first-boot + `systemd-factory-reset`** | soon | medium | low | Fedora 43 ships 258. WSL2/Hyper-V VHD resize story. |
| 11 | **Bazzite parity: `setup-virtualization`, `setup-vfio`, `setup-waydroid`, `setup-sunshine` `ujust` recipes + bazzite-org/gamescope fork** | feature catch-up | medium | medium | bazzite-org gamescope carries real CVE patches (stb_image). |
| 12 | **Open NVIDIA kmod default** for CloudWS-1 (`kmod-nvidia-open`) with proprietary escape hatch build-arg | upcoming | small | medium | RTX 4090 at 4K/240Hz under GSP has a documented compositor regression; gate with test. |
| 13 | **NVIDIA-VM gating** — blacklist nvidia kmods by default, coldplug-detect in `34-gpu-detect.sh` on bare metal only | latent bug | small | low | Project rule already states this; verify it's implemented. Never ship `nvidia-drm.modeset=1` unconditionally. |
| 14 | **Rechunker retention + bootc-base-imagectl migration plan** + weekly GHCR cleanup (keep 7 most-recent untagged) | hygiene | small | low | hhd-dev/rechunk is external; bootc-base-imagectl is the upstream-sanctioned successor. |
| 15 | **Signed `/etc` confext (systemd 258+)** replacing most `system_files/etc/` overlays — v2.5 target, NOT v2.4 | architectural | large | medium | Flatcar already ships this in production (March 2026). Needs signing CI, verity root-hash rotation, root image policy. |

---

## Part 1 — six focused work items

### 1.1 — WSL-spawn fix for Claude Code on Windows 11

**Precise problem.** Claude Code's Bash tool resolves `bash` via PATH; on Windows 11 `C:\Windows\System32\bash.exe` is a WSL launcher stub. Confirmed process tree:
```
claude.exe
 └─ C:\Windows\System32\bash.exe   (WSL launcher stub)
     └─ wsl.exe
         └─ wslhost.exe            (COM/RPC broker)
             └─ bash (inside WSL VM)
```
`wslhost.exe` briefly acquires a console → visible popup. Every tool call flashes a window. VSCodium's Claude Code side-panel ignores `.vscode/settings.json` terminal keys.

**Current state.** No fix applied. System32 is first on Machine PATH; User-PATH edits alone cannot beat it (Windows logon concatenates Machine-first, then User).

**Upstream (authoritative):**
- Anthropic Windows setup page: *"Claude Code uses Git Bash internally … set the path in settings.json."* Officially-documented env var is **`CLAUDE_CODE_GIT_BASH_PATH`**.
- The task's proposed names `BASH_DEFAULT` and `CLAUDE_CODE_BASH_PATH` **do not exist** in the reference. `BASH_DEFAULT_TIMEOUT_MS` is a timeout, not a selector.
- `CLAUDE_CODE_SHELL` exists but issue **anthropics/claude-code#21843** (Feb 2026) reports it is ignored on Windows — treat as community claim, not spec; use `CLAUDE_CODE_GIT_BASH_PATH` instead.
- Related reports: anthropics/claude-code **#21800, #26006, #12022, #25593**, anthropics/claude-quickstarts **#306**.
- Git for Windows wrapper: `C:\Program Files\Git\bin\bash.exe` is the **wrapper stub** that execs `usr\bin\bash.exe` with `MSYSTEM` set; **does NOT open MinTTY** (that's `git-bash.exe`).
- Putting only `bin\` on PATH (not `usr\bin\`) avoids shadowing Windows `find.exe`/`sort.exe`/`tar.exe`.
- Microsoft: PATH merge order (HKLM then HKCU concatenated) is immutable at logon. Hence env-var is primary, PATH is fallback.

**Recommended approach.** Two layers, both idempotent, no admin:
1. **Primary:** set User env `CLAUDE_CODE_GIT_BASH_PATH=C:\Program Files\Git\bin\bash.exe` AND mirror into `~/.claude/settings.json` `{"env":{...}}`.
2. **Fallback:** prepend `C:\Program Files\Git\bin` to User PATH (and Machine PATH if elevated).

**Deliverable shape (standalone fix script, NOT a push script):**
- `#Requires -Version 7.0`, `Set-StrictMode -Version 3.0`
- Verify the path resolves to Git bash and NOT System32 before setting
- Never use `Invoke-Expression`; no empty `catch {}`
- Validate with `& $BashPath -c 'echo UNAME=$(uname -s)'` and refuse to set if it resolves to the System32 stub

**Caveats.** Machine PATH beats User PATH — PATH reorder alone is insufficient. VSCodium must be fully restarted for env changes to propagate. Never point at `git-bash.exe` (opens MinTTY). Do not put `usr\bin` on PATH (shadows Windows utilities). `CLAUDE_CODE_USE_POWERSHELL_TOOL=1` is complementary.

---

### 1.2 — Cosign keyless signing + release pipeline polish

**Precise problem.** Repo has key-based cosign artifacts and pub keys but the pipeline is under-wired. Goal: polish to current 2026 best practice without regressing bootc upgrade verification.

**Upstream landscape (the critical finding).**

| Project | Keyless? | Key-based? | SBOM mechanism | policy.json |
|---|---|---|---|---|
| ublue-os/main, bluefin, aurora, bazzite | **NO** | **YES** via `secrets.SIGNING_SECRET`/`COSIGN_PRIVATE_KEY` | **oras attach** (since bluefin PR #4274), not `cosign attest` — Rekor rejects large SBOMs | key-based `sigstoreSigned` referencing repo-committed `cosign.pub` |
| SecureBlue | NO (key-based) + **SLSA provenance verification on update** | YES | n/a | ships at `/usr/etc/policy.json` (PR #607) |

**DeepWiki summaries that say ublue uses "keyless" are wrong** — the YAML uses `COSIGN_PRIVATE_KEY`. Ublue explicitly deferred keyless because `containers/image` support was immature.

**Critical 2026 blocker:** **Cosign v3 enables `--new-bundle-format` by default**, which **rpm-ostree/bootc cannot verify** (rpm-ostree issue #5509). Builders must pin cosign v2 or pass `--new-bundle-format=false`. Applies equally to CloudWS. The blessed path is: cosign **v2.6.x**, stay key-based for now, **add keyless signatures in parallel** as a future consumer path.

**bootc enforcement reality:**
- `bootc install` / `bootc switch` have `--enforce-container-sigpolicy` (issue **#218**, **#528**).
- `bootc upgrade` **does NOT have** the flag. Day-2 enforcement relies on default-reject policy.json + `use-sigstore-attachments: true`.

**Recommended approach (pragmatic, not aspirational).**
1. Keep cosign **v2.6.x** pin. Keep key-based signing (existing `cloudws-cosign.pub`).
2. **Add keyless signing in parallel** to every pushed tag — a second signature the policy can optionally enforce later.
3. Set `use-sigstore-attachments: true` in every registries.d entry.
4. Build policy.json with **both** `sigstoreSigned` variants (key + keyless) OR'd via multiple list entries.
5. SBOM: generate with syft (SPDX + CycloneDX), attach via **`oras attach`** (not `cosign attest`) — follow bluefin PR #4274 precedent.
6. Verify ublue base image chain in CloudWS-2 build via `EyeCantCU/cosign-action/verify` against upstream `cosign.pub`.
7. Weekly GHCR cleanup via `actions/delete-package-versions@v5` (keep 7 most-recent untagged, preserve tagged).
8. `id-token: write` scope only on the `sign` job.

**Caveats.** **Do not switch to cosign v3 until rpm-ostree/bootc container-libs adopt the new bundle format** — track rpm-ostree#5509.

---

### 1.3 — FreeIPA / SSSD integration completion

**Precise problem.** `tmpfiles.d/cloudws-freeipa.conf` is a stub. Full first-boot enrollment flow missing.

**Key Bugzilla items:**
- **bz 2332433** — `ipa-client-install` fails on Atomic because `/var/lib/ipa-client/sysrestore/` missing. Fix: pre-create via tmpfiles.d.
- **bz 2320133** — rpm-ostree layering strips xattr capabilities from SSSD (`krb5_child`, `ldap_child`, `selinux_child`, `sssd_pam` lose `cap_dac_read_search`). **Fixed in bootc >= 1.1.2-2.fc41**. Assert `getcap` on these post-layer.
- **bz 2417703** (Nov 2025) — sssd_be crashes under bootc+IPA; workaround `selinux_provider = none` in `[domain/REALM]`.
- `/etc` in bootc is **3-way merged on upgrade** but **replaced on `bootc rollback`**. `/var` persists unconditionally → marker must live in `/var`.

**Recommended approach.**
1. Layer RPMs: `freeipa-client sssd sssd-ipa authselect oddjob oddjob-mkhomedir certmonger krb5-workstation` with `dnf --exclude=kernel*`.
2. Opt-in: service only runs if `/etc/cloudws/ipa.conf` exists (`ConditionPathExists`).
3. Idempotent: completion marker `/var/lib/cloudws/ipa-enrolled`.
4. Ship domain-agnostic drop-in `10-cloudws.conf`; helper writes realm-specific `20-cloudws-domain.conf` with `selinux_provider = none` at enrollment.
5. Build-time regression check for SSSD file capabilities; fail build if dropped.
6. Use stock `sssd` authselect profile.
7. Prefer OTP-pre-created host (`ipa host-add --random`) over admin principal + password.

**Caveats.** `authselect` clobbers `/etc/pam.d/*` and `/etc/nsswitch.conf` at enrollment — never ship hand-edited PAM. `ipa-client-install` requires DNS + clock skew < 5 min. On `bootc rollback` pre-enrollment, admin must manually `ipa-client-install --uninstall -U && rm /var/lib/cloudws/ipa-enrolled`. AD trust / IPA-IPA replication explicitly out of scope.

---

### 1.4 — kargs.d schema validator in pr-lint

**Precise problem.** Copilot keeps emitting `[kargs]` section headers and invented `delete`/`delete_kargs` sub-keys. bootc rejects either silently or at build time; CI should catch at PR time in seconds.

**Upstream schema (authoritative allow-list):**
- Sources: bootc.dev/bootc/building/kernel-arguments.html, RHEL 10 image-mode docs Ch. 12, bootc PR **#1783**, bootc discussion #171, bootc issue #255.
- **Only two top-level keys allowed:** `kargs` (array of strings, required) and `match-architectures` (array of strings, optional).
- **Forbidden:** any `[section]` header; any `delete`/`delete_kargs`/`remove`/`kargs_delete`; non-string entries; space-joined kargs in a single entry.
- A **separate, different** schema exists at `/usr/lib/bootc/install/*.toml` using `[install]` table — a likely Copilot confusion source.

**Recommendation.** Python 3.11+ stdlib `tomllib`, no third-party deps. Ship as a **new** workflow file `.github/workflows/kargs-lint.yml` — additive, does not touch `pr-lint.yml`.

**Deliverables:**
- `scripts/validate-kargs.py` — ~200 LoC. Walks `kargs.d/*.toml` and `system_files/usr/lib/bootc/kargs.d/*.toml`. Raw-text scan for `[section]` headers (line-localized), then tomllib parse, then structural checks. Modes: human / `--github` (annotations) / `--json`. Exit 0 pass / 1 fail / 2 usage.
- `.github/workflows/kargs-lint.yml` — `on: [pull_request, push main]` scoped to `kargs.d/**`, `actions/setup-python@v5` with 3.12, concurrency group, `timeout-minutes: 3`, `permissions: contents: read`.

**Caveats.** `tomllib` is 3.11+. Space-in-karg rule flags legitimately weird but functioning entries — documented. **Deliver as a new workflow file** rather than patching `pr-lint.yml`.

---

### 1.5 — Composefs post-pivot path verification expansion

**Precise problem.** Existing `verify-root.sh` checks 8 paths. `/etc/containers/policy.json` isn't covered at all — swap it to `insecureAcceptAnything` and all image verification dies silently. Failure is not wired to greenboot rollback.

**Upstream reality check:**
- **Fedora bootc defaults to `composefs.enabled = yes` (UNSIGNED)** — integrity against accidental mutation, not against attackers with root.
- composefs covers `/usr` (and anything in the image). Does NOT cover `/etc` (overlay), `/var`, or `/boot`.
- **No `bootc verify` subcommand exists** as of bootc 1.15.0 (March 2026).
- `fsverity measure` is **constant-time** (reads cached Merkle root) — cheap.

**Three-tier strategy:**
- **Tier A — existence** (~22 paths). Cheap. Any missing => fail.
- **Tier B — fsverity measure** (optional, reads `/usr/lib/cloudws/verify-root.digests`). Silently skips on files without fs-verity. No-op under default unsigned composefs — document this clearly.
- **Tier C — `policy.json` sha256** against `/usr/lib/cloudws/policy.json.sha256` (baseline ships under `/usr` so it's composefs-covered).

**Deliverables:**
- `system_files/usr/libexec/cloudws/verify-root.sh` — set -euo pipefail, three tiers, `systemd-cat`-friendly output, exit 0/1.
- `system_files/etc/greenboot/check/required.d/10-cloudws-composefs.sh` — thin wrapper; non-zero => greenboot retry/rollback.
- `system_files/usr/lib/systemd/system/cloudws-verify-root.service` — oneshot, `Before=greenboot-healthcheck.service basic.target`, full hardening.
- `docs/COMPOSEFS-VERIFICATION.md` — explains chain, why IMA/EVM skipped, Tier B no-op on unsigned composefs, /etc drift semantics, escape hatch.

**Caveats.** Tier B is a no-op under Fedora bootc defaults. Tier C false positive when user legitimately edits `policy.json` will cause rollback loop — escape-hatch documented.

---

### 1.6 — Secure Boot MOK enrollment automation polish

**Precise problem.** MOK enroller "ongoing refinement"; idempotency, CloudWS-1 vs CloudWS-2 variant detection, and TPM2 PCR7 re-seal UX all missing.

**Upstream facts (the decisions that matter):**
- **Use `mokutil`, not `sbctl`.** Fedora bootc uses **GRUB2 + shim** (Red Hat-signed shim via MS UEFI CA). sbctl is for users who own firmware PK/KEK/db (sd-boot/UKI). Wrong tool here.
- bootc UKI/systemd-boot support tracked in **bootc#806** (opened 2024-09-27); GRUB2+shim remains the Fedora bootc default as of April 2026.
- **CloudWS-2 (ucore-hci) ships pre-signed NVIDIA kmods with the Universal Blue signing key** at `/etc/pki/akmods/certs/akmods-ublue.der`. Still needs one-time MOK enrollment, but of the **ublue key**, not a CloudWS key. The enroller must detect variant.
- Ublue's convention: password `universalblue` hard-coded. CloudWS should use **`mokutil --import --root-pw`** instead.
- **MokManager at first boot requires physical-presence keypress** — by design, cannot be automated.
- **TPM2 PCR 7 changes on every MOK mutation.** Every LUKS slot sealed with `systemd-cryptenroll --tpm2-pcrs=7` will fail to auto-unlock. Document the re-seal command loudly.
- **4096-bit RSA MOK keys hang some shim versions** (Debian wiki 2022). Use 2048.
- Known hardware quirk: `mokutil --timeout -1` silently fails on ASUS H97i-class. Don't `set -e` on that call.

**Recommended approach.**
1. `mokutil` throughout. `sbctl` only if/when bootc flips to UKI (bootc#806 lands).
2. Variant detection: `pick_key()` prefers `/etc/pki/cloudws/mok.der`, falls back to `/etc/pki/akmods/certs/akmods-ublue.der`.
3. Idempotent guards: `mokutil --sb-state` short-circuit, SHA-256 fingerprint compare.
4. `--root-pw`, not a shipped secret.
5. Rollback on failure via `mokutil --revoke-import`.
6. Structured log to `/var/log/cloudws/mok-enroll-<ISO>.log`.
7. Status probe prints one of: `enrolled | pending | not-enrolled | no-secureboot | conflict`.

**Deliverables:**
- `scripts/enroll-mok.sh` — `set -euo pipefail`, variant-aware, idempotent, rollback, PCR7 re-seal notice in final banner.
- `scripts/generate-mok-key.sh` — one-shot, encrypted PEM key + DER cert + base64 + SHA-256 fingerprint, refuses to overwrite, 2048-bit, 10-year validity.
- `system_files/usr/libexec/cloudws/mok-enroll-status` — machine-readable probe.
- `docs/SECUREBOOT.md` — ~300 LoC: chain diagram, MOK vs db/KEK/PK table, CloudWS-1 vs CloudWS-2 paths, **PCR7 re-seal command**, MokManager UI walkthrough, troubleshooting.

**Caveats.** Cannot be fully automated (by design — physical presence). Do NOT regenerate the MOK key per-build. SBAT mismatches independent of MOK can soft-brick boot — track Fedora shim releases.

---

## Part 2 — bootc ecosystem scan (2025–2026)

### Red Hat / bootc core

**bootc-dev/bootc** — Core CLI/library; **now CNCF Sandbox project (Jan 21 2025)**; repo moved from `containers/bootc` to `bootc-dev/bootc`. Release train Sep 2025 → v1.15.0 (Mar 31 2026). Relevance: **critical**.

Notable 2025-2026:
- **v1.15.0 (Mar 31 2026):** `usroverlay --readonly`; tag-aware upgrade; cached-update info in status; composefs proxy-auth + missing-verity + pre-flight disk-space check.
- **v1.14.0 (Mar 11 2026):** `bootc upgrade` pre-flight disk space; composefs enforcing SELinux for sealed images; composefs GC.
- **v1.13.0 (Feb 23 2026):** `bootloader=none` install; **`bootc container ukify`** command (foundation for future UKI workflow); shell completions.
- **v1.12.0 (Jan 6 2026):** `bootc upgrade --download-only` / `--from-downloaded`; `bootc container inspect`; experimental unified storage.
- **v1.11.0 (Dec 5 2025):** factory reset flow (experimental); kargs from `usr/lib/bootc/kargs.d` **confirmed landed**.
- **v1.9.0 (Oct 8 2025):** composefs-native backend merged; structured journal logging.
- Security: **no CVEs** in bootc-dev/bootc as of April 2026.

**CloudWS adoptions:**
1. Move to `--download-only` + `--from-downloaded` pattern for graceful upgrades.
2. Adopt pre-flight disk-space (free after 1.14 — nothing to do).
3. Track `bootc container ukify` for the eventual MOK→UKI migration (item 1.6's future state).
4. Adopt `factory reset` flow in WSL2/Hyper-V deploys once stable.

**bootc-image-builder** — Supported targets: `ami, anaconda-iso, bootc-installer, gce, iso, qcow2, raw, vhd, vmdk` — **VHD but no VHDX** (open issue #172), **no native WSL2/tarball**.

**CloudWS applicability:**
1. VHDX generation: BIB doesn't natively support it — **continue to convert VHD→VHDX post-BIB with qemu-img or PowerShell**.
2. WSL2 tarball: pipeline stays custom (`tar` export from bootc image).
3. Anaconda-iso: adopt `application_id` / `publisher` / `volume_id` customizations.

**bootc-base-imagectl + rechunk** — Relevance: **medium**.
- `hhd-dev/rechunk` remains the de-facto rechunker; **ublue devs now recommend planning migration to `bootc-base-imagectl`** — rechunk is "hard to remove."
- **rpm-ostree `build-chunked-oci`** (Nov 3 2025) — assign specific files to specific layers.
- **Dec 2025 bootc blog:** current rechunking duplicates unchanged directories across layers, which blocks a future composefs+fsverity "image measures itself" reproducibility goal.

**CloudWS adoption:** continue hhd-dev/rechunk short-term; plan `bootc-base-imagectl rechunk` migration when F43/bootc 1.15 is stable in prod.

**RHEL image mode** — GA since June 2025; RHEL 10.1 (Nov 12 2025) **ships soft-reboot as default update path** for bootc image mode.

**Fedora Atomic + bootc-ification:**
- **Fedora 43** released Oct 28 2025. zstd-compressed initrds; 2GB /boot default.
- **Fedora 44 beta** released Mar 10 2026; final Apr 14 2026; Linux 6.19; **GNOME 50** (removes X11); KDE Plasma 6.6.
- bootc-ification of Silverblue/Kinoite blocked on releng#12142 + issue #44.

**Podman / Quadlet 2025–2026** — **Podman 5.6 (Aug 2025)** introduced unified `podman quadlet` CLI suite; all unit types expanded. New `AppArmor=` key in `.container`. `podman quadlet install` supports multi-file bundles. **Podman 6 in active development, target early 2026.**

**CloudWS adoptions:**
1. Migrate CrowdSec and other sidecar services to Quadlets.
2. **Keep K3s as native systemd service, NOT Quadlet** — its kubelet+containerd are host-level.
3. Use `.build` quadlets for any in-situ image assembly if needed.

---

### Universal Blue family

**Cross-family adoption summary:**
1. **Enable `ublue-os/packages` COPR and layer:** `uupd`, `ublue-os-just`, `ublue-polkit-rules`, `ublue-rebase-helper`, `ublue-os-nvidia-addons`, `ublue-os-libvirt-workarounds`.
2. **Adopt `ujust` + numbered justfiles** under `/usr/share/ublue-os/just/NN-cloudws-*.just`.
3. **Sidecar-layer pattern** — `COPY --from=ghcr.io/ublue-os/config:latest /files/etc/udev/rules.d/ /usr/lib/udev/rules.d/`; pull ublue fonts/bling incrementally.
4. **uupd for unified updates** (flatpak + distrobox + brew + bootc) with systemd timers. Must set `AutomaticUpdatePolicy=none` in rpm-ostreed.conf.

**ublue-os/ucore + ucore-hci (CloudWS-2 parent)** — actual delta over ucore is confirmed small: `cockpit-machines`, `libvirt-client`, `libvirt-daemon-kvm`, `virt-install`. Known libvirtd 45s shutdown-timeout caveat — ship `/etc/systemd/system/libvirtd.service.d/10-cloudws.conf` with `TimeoutStopSec=120s`. **Sister project `ublue-os/cayo`** is the bootc-native HCI successor — watch for CloudWS-2 migration path. ucore multi-arch (aarch64+x86_64) as of 20251108.

**Gamescope Steam session (Bazzite)** — files to mirror:
- `/usr/bin/steamos-session-select` + `create_sentinel` flag.
- `/etc/sddm.conf.d/10-autologin.conf` with session type `gamescope-session.desktop`.
- Env via `~/.config/environment.d/gamescope-session-plus.conf`.
- **Use `bazzite-org/gamescope` fork** — stb_image CVE patches (CVE-2021-28021/42715/42716, CVE-2022-28041, CVE-2023-43898, CVE-2023-45661..45667). Not optional.
- Known #1902 (Jun 2025): global shortcuts broken when nested in Wayland session — workaround `--backend sdl`.

**Waydroid (Bazzite)** — `ujust setup-waydroid`:
1. Enable `waydroid-container.service` (rootful systemd service, NOT Quadlet).
2. `sudo waydroid init -c https://ota.waydro.id/system -v https://ota.waydro.id/vendor -s GAPPS -f`.
3. **`restorecon /var/lib/waydroid`** — non-optional.
4. **Does NOT work on NVIDIA proprietary** — AMD/Intel only.

Waydroid 1.6.0 (Nov 2025) adds notification forwarding + manual ADB.

**Looking Glass B7** — `ujust setup-virtualization`:
- VFIO kargs: `intel_iommu=on`/`amd_iommu=on`, `iommu=pt`, `rd.driver.pre=vfio-pci`, `vfio_pci.disable_vga=1`.
- `/etc/modprobe.d/kvmfr.conf` with `options kvmfr static_size_mb=128` (CloudWS 4K: bump to **256 MB**).
- udev rule for `/dev/kvmfr0`: `SUBSYSTEM=="kvmfr", OWNER="kabu", GROUP="kvm", MODE="0660"`.
- **Libvirt XML: `memballoon type='none'`** — non-negotiable for perf.
- **Build LG client with `-DENABLE_LIBDECOR=ON`** — GNOME Wayland lacks xdg-decoration.
- Host + client version must match exactly.

**NVIDIA CDI (ucore/GDX pattern):**
- Package `ublue-os-nvidia-addons` from COPR.
- `/usr/lib/systemd/system/ublue-nvctk-cdi.service` — runs `nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml` at boot.
- Custom SELinux module `nvidia-container.pp`.
- **Pin nvidia-container-toolkit — NOT 1.17.8** (caused "unresolvable CDI devices"). 1.17.6 or 1.18+/1.19.0 are OK.
- **Remove `/usr/share/containers/oci/hooks.d/oci-nvidia-hook.json`** — dual injection with CDI causes conflicts.

**SecureBlue** — adopt OPT-IN hardenings only.

**Pull (via `ujust harden-*`):**
- KSPP-style sysctl: `kernel.dmesg_restrict=1`, `kernel.kptr_restrict=2`, `kernel.kexec_load_disabled=1`, `kernel.unprivileged_bpf_disabled=1`.
- Kernel kargs: `page_poison=1 init_on_alloc=1 init_on_free=1 slab_nomerge vsyscall=none lockdown=integrity`.
- `audit_flatpak_permissions()` Python module.
- Flatpak overrides: narrow `--filesystem=host`, remove blanket `--device=all`.
- MAC randomization + DoT selector.

**AVOID for a dev workstation (these will actively break CloudWS):**
- Global `hardened_malloc` preload — **breaks** Electron, CUDA, Steam Proton.
- Unprivileged userns disabled in SELinux — **breaks** `podman run --userns=auto`, `distrobox create`, rootless k3d/kind.
- XWayland disabled by default — **breaks** VSCode, Discord screenshare, OBS capture.
- Trivalent-only browser policy — **breaks** web-dev workflow.
- SUID-Disabler + Permission Hardener — **breaks** sudo + many dev tools.
- `noexec` on `/home` — **breaks** node_modules execution, local build artifacts, pip-installed binaries.
- `lockdown=confidentiality` — **breaks** debuggers, eBPF, perf.

---

### Other immutable distros

**Kairos** — Trusted Boot + UKI reference implementation. `auroraboot build-uki` with active/passive/recovery/auto-reset entry taxonomy. **Adopt the entry taxonomy** when CloudWS migrates to UKI.

**Talos v1.10/1.12** — **all UEFI installs use systemd-boot + UKI**. v1.12 `ImageVerificationConfig` = machine-wide cosign enforcement. Relevance: low-med.

**Flatcar Container Linux (Mar 3 2026 release)** — **`/etc` is now shipped as a systemd-confext** in prod. Proof that confext is ready. CloudWS v2.5 target.

**openSUSE Aeon FDE-by-default** — TPM 2.0 v1.38 PolicyAuthorizeNV sealing. Relevant reference for CloudWS LUKS+TPM2 story.

**CoreOS heritage / soft-reboot** — bootc **issue #1350** tracks soft-reboot. Fedora 43 timeframe. `bootc upgrade --apply` auto-uses soft-reboot. **CloudWS mitigation:** post-soft-reboot unit that re-applies firewalld + podman network rules.

**HeliumOS 10** (Jul 28 2025) — CentOS Stream / Alma base, Plasma 6.4.2, kernel 6.12 LTS. **`bootc-gtk`** (Python/GTK4) is interesting as alternative GUI bootc frontend — watch.

---

### Core userspace

**systemd 258 (GA Sep 17 2025) features relevant to CloudWS:**
- `systemd-factory-reset` — adopt for WSL2/Hyper-V re-provisioning.
- systemd-stub loads global sysexts/confexts from ESP — foundation for v2.5 signed-confext rewrite of `system_files/etc/*`.
- `systemd-repart` gains **file-level fs-verity checks**.
- **cgroupv1 removed** — Linux >= 5.4 required.

**dracut-ng** — dracut-ng 100 = drop-in replacement for unmaintained dracut. Fedora 41+ already cut over. `hostonly=no` mandatory for bootc image builds. **No CloudWS-specific change needed**.

**akmods 2025–2026:**
- **CentOS Kmods SIG** now provides `kmod-nvidia-open`, `kmod-nvidia-open-570`, `kmod-nvidia-580` for EL 8/9/10 — pre-built, signed kmods. Consider adopting to skip local akmods compilation.
- Known F42 bootc bug: akmods fails on `/var/tmp` perms. Workaround `chmod 777 /var/tmp` + fake-uname + `akmods --force --kernels ${kver}`.
- **Pin akmod-nvidia version and assert kmod RPM is produced** (Fedora discussion #145586 Feb 2025).

**NVIDIA 2025–2026 (critical for RTX 4090):**
- NVIDIA **officially recommends Open kernel modules** for Turing/Ampere/Ada/Hopper (all of which include RTX 4090).
- **Caveat for RTX 4090:** cannot disable GSP firmware; reported desktop-compositor regression at 2560×1440@240Hz with KWin (Arch BBS #300747). **Validate on 9950X3D+4090 hardware** before defaulting to Open.
- **NCT v1.19.0 (latest):** read-only rootfs support (critical for bootc).
- NCT v1.18.0: `nvidia-cdi-refresh.service` introduced.
- Canonical CDI: `/var/run/cdi/nvidia.yaml` (runtime) or `/etc/cdi/nvidia.yaml` (persistent).
- Podman >= 4.1 native `--device nvidia.com/gpu=all`.

**GNOME 50 (released Mar 18-19 2026, codename Tokyo) — Wayland-only:**
- **X11 session removed from source.** GDM 50 never runs Xorg. Mutter/Shell X11 removal PRs merged Nov 5 2025.
- XWayland retained for apps.
- **Ubuntu 26.04 LTS and Fedora 44 ship GNOME 50.**

**GNOME 50 → xRDP impact (critical):**
- **xRDP/xorgxrdp is dead on GNOME 50**. xrdp 0.10.4/0.10.5, xorgxrdp 0.9.27 — no Wayland backend, **no roadmap**.
- **Replacement: `gnome-remote-desktop`** — built into GNOME via Mutter MR #139; native RDP+VNC; headless multi-user via GDM integration.
- **CloudWS must migrate.** Remove `xrdp`, `xorgxrdp`, `xorgxrdp-glamor` from packages. Ship `gnome-remote-desktop` with `grdctl` provisioning.

**Cockpit:**
- **349 + cockpit-podman 115** — Quadlet detection.
- **346 + cockpit-machines 339** — Stratis V2, serial console preservation.
- Ship `cockpit cockpit-podman cockpit-machines cockpit-storaged cockpit-files cockpit-selinux` in CloudWS-2 as RPM layer.
- Fix the libvirt-socket race: systemd override `cockpit.socket.d/10-cloudws.conf` with `After=libvirtd.socket`.

**K3s, Ceph, Pacemaker on bootc:**
- K3s: native systemd service + Quadlet sidecars. No upstream "K3s on bootc" doc; inferred from Red Hat best-practices article (Feb 2025).
- Ceph: cephadm-bootstrap is natural fit (already container-native); `/var/lib/ceph/` as persistent state. **Speculative pattern — no first-party doc**.
- Pacemaker/Corosync: `/var/lib/pacemaker/cib/` + `/var/lib/corosync/` persistent; config via confext. **Speculative**.

**CrowdSec:**
- v1.7.3 (Oct 24 2025) → v1.7.6 (early 2026).
- Switched to RE2 regex engine — faster grok, slightly higher memory.
- Ship as Quadlet (`crowdsecurity/crowdsec:v1.7.6-debian`) with `datasource_journalctl` ingesting host journal directly.
- `cs-firewall-bouncer` as host RPM (needs nftables).
- **Pin `:v1.7.6`, not `:latest`**.

---

## Part 3 — integrated findings + recommended push order

### Blocking right now
1. **WSL popups (item 1.1)** — degrades every interactive dev session. Ship standalone `fix-claude-bash.ps1` TODAY.
2. **kargs.d validator (item 1.4)** — soft-blocking Copilot-assisted work. One-day deliverable.

### Low-risk high-value quick wins (v2.3.8 / v2.3.9)
3. `use-sigstore-attachments: true` across registries.d.
4. Remove `oci-nvidia-hook.json`; ship `nvidia-cdi-refresh.service`; pin nvidia-ctk version.
5. Enable `ublue-os/packages` COPR; layer `uupd`, `ublue-os-just`, `ublue-polkit-rules`, `ublue-rebase-helper`, `ublue-os-libvirt-workarounds`.
6. `libvirtd.service.d/10-cloudws.conf` `TimeoutStopSec=120s`.
7. Bazzite-style `ujust setup-virtualization`/`setup-vfio`/`setup-waydroid`/`setup-sunshine`.
8. `bazzite-org/gamescope` fork instead of upstream Valve gamescope (stb_image CVE patches).
9. Composefs verify-root expansion (item 1.5) — additive, no runtime risk.
10. MOK enroller polish (item 1.6) — replaces current script, better UX.

### Medium-lift (v2.4.0 cut)
11. **xRDP → gnome-remote-desktop migration** — must land before F43/GNOME 50 rebase.
12. FreeIPA/SSSD completion (item 1.3) — opt-in, no forced cost.
13. Cosign keyless **in parallel** (dual signatures), keep key-based enforced.
14. Open NVIDIA kmod default with proprietary escape hatch build-arg (requires 4K/240Hz hardware validation on Kabu's 9950X3D+4090 box).
15. Soft-reboot integration when bootc#1350 lands.

### Architectural (v2.5.0+)
16. Signed `/etc` confext replacing most `system_files/etc/` overlays (Flatcar-proven, systemd 258+).
17. UKI signing pipeline via `bootc container ukify` + dracut-ng/ukify + Kairos entry taxonomy.
18. TPM2 PCR11 measured boot when on UKI.
19. Migration to `bootc-base-imagectl rechunk` from hhd-dev/rechunk.
20. CloudWS-2 consideration of `ublue-os/cayo` as bootc-native HCI successor to ucore-hci.

### Explicitly DO NOT pull
- **Cosign v3** with default `--new-bundle-format` — breaks rpm-ostree/bootc (rpm-ostree#5509). Stay on v2.6.x.
- **nvidia-container-toolkit v1.17.8** — "unresolvable CDI devices" regression. Use 1.17.6 or 1.18+/1.19.0.
- SecureBlue's **global `hardened_malloc` preload**.
- SecureBlue's **userns disabled in SELinux** (breaks Podman rootless, distrobox, Bubblejail).
- SecureBlue's **XWayland disabled by default** (breaks VSCode/Discord/OBS).
- SecureBlue's **noexec on /home** (breaks node_modules).
- SecureBlue's **lockdown=confidentiality** (breaks debuggers/eBPF).
- SecureBlue's **Trivalent-only browser policy**.
- **sbctl** — wrong tool for Fedora bootc GRUB2+shim chain.
- **gnome-session-xsession** — does not exist (project rule, reconfirmed).
- `GTK_THEME=Adwaita:dark` — breaks libadwaita; use `ADW_DEBUG_COLOR_SCHEME=prefer-dark` (project rule).
- `xorgxrdp` + `xorgxrdp-glamor` coexistence — conflict. On GNOME 50 **remove both entirely**.
- Unconditional `nvidia-drm.modeset=1` / `nvidia-drm.fbdev=1` kargs — breaks GPU-less VMs (project rule).
- `((VAR++))` under `set -e` — exits when VAR=0. Use `VAR=$((VAR + 1))`.

### Proposed sequencing (2–3 push scripts)

**push-238-dev-ergonomics.ps1** (urgent):
- Standalone `fix-claude-bash.ps1` shipped to Kabu's dev box (not a repo push; local apply).
- Add `scripts/validate-kargs.py` + `.github/workflows/kargs-lint.yml`.

**push-239-signing-and-ublue.ps1** (low-risk, high-value):
- Full replacements: `build-sign.yml` (v2.6 cosign pin + dual signing + oras attach SBOM), `policy.json`, `registries.d/*.yaml`, `scripts/42-cosign-policy.sh`, `scripts/verify-image-signature.sh`.
- ublue-os/packages COPR + uupd enablement: `scripts/NN-ublue-packages.sh`, `/etc/rpm-ostreed.conf`, `ujust` justfile skeleton.
- Libvirt workarounds drop-in.
- NVIDIA CDI: `ublue-nvctk-cdi.service` + remove oci-nvidia-hook.json + pin nvidia-ctk.

**push-240-verification-and-mok.ps1** (additive defense-in-depth):
- Composefs verify-root expansion (item 1.5).
- MOK polish (item 1.6).
- FreeIPA stack (item 1.3).

### Hard-rule compliance audit of this plan
- All deliverables are **complete replacement files**; no patches/diffs. ✓
- All kargs.d files shipped remain **flat top-level `kargs = [...]` only**; validator enforces. ✓
- Protected files (VERSION, CHANGELOG.md, docs/PACKAGES.md, .ai-context/knowledge-base.md) **not touched**. ✓
- All PowerShell 7+ (`#Requires -Version 7.0`), no `Invoke-Expression` on remote content, no empty catch. ✓
- All bash `set -euo pipefail`; no `((VAR++))`; shellcheck-fatal rule set honored. ✓
- Containerfile rules preserved: no kernel/kernel-core upgrade. ✓
- NVIDIA/VM gating: no unconditional `nvidia-drm.modeset=1`; CDI-refresh adoption assumes `34-gpu-detect.sh` blacklist-by-default is already in place (verify). ✓
- GNOME 50 plan: drops xorgxrdp+xorgxrdp-glamor conflict entirely; replaces with gnome-remote-desktop. ✓

### Flagged uncertainties
- **Cayo** as CloudWS-2's future base: exists but maturity level not independently verified — monitor, don't commit.
- **HeliumOS ↔ ublue** collaboration: proposed (ublue-os/main#714), not consummated as of April 2026.
- **GSP firmware on Open for RTX 4090 at 4K**: single documented regression at 2560×1440@240Hz on KWin. Validate on GNOME Mutter at 4K before defaulting to Open.
- **Ceph-on-bootc and Pacemaker-on-bootc**: no first-party upstream doc; inferred patterns only.
- **bootc soft-reboot (`--skip-soft-reboot`)**: issue #1350 open since Jun 3 2025; assume Fedora 43 timeframe but verify at release time.
- **GNOME 50 release date**: March 18 vs March 19 2026 depending on source timezone. Use "mid-March 2026" when writing docs.
- **`CLAUDE_CODE_SHELL` ignored on Windows**: single community bug (#21843); don't rely on it — `CLAUDE_CODE_GIT_BASH_PATH` is the load-bearing variable per Anthropic docs.
- **DeepWiki summaries** claiming ublue uses "keyless signing" are contradicted by the underlying workflow YAML which uses `COSIGN_PRIVATE_KEY`. Always cross-check YAML over summary.

### Source quality note
Primary sources used throughout: bootc-dev/bootc releases + issues, ostreedev/ostree docs, sigstore/cosign docs, containers/image manpages, fedora-iot/greenboot README, kernel docs (fsverity), ublue-os GitHub repos, Anthropic code.claude.com docs, GitHub issue trackers, systemd/systemd releases, FreeIPA project docs, Red Hat image-mode docs, Fedora Wiki, ArchWiki (sbctl/systemd-cryptenroll), shim/mokutil manpages. Secondary (flagged where material): DeepWiki summaries, community blogs (c-nergy.be, mrguitar.net, tim.siosm.fr), Phoronix, Linuxiac, The Register. DeepWiki summaries of AI-indexed repos are specifically flagged where they conflict with authoritative YAML.

---

*Dated: April 19, 2026. Append new entries; do not modify existing findings.*
