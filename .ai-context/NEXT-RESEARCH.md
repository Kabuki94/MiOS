# NEXT-RESEARCH — agenda for next scheduled-research pass

> Written by `scheduled-research-daily` on 2026-05-16 (UTC). Tomorrow's run should start here.

---

## ACTION REQUIRED items (carry forward until resolved)

These are upstream signals that imply a build-breaking or security change to the project. **The research agent never applies these.** They are surfaced here for human review and follow-up.

1. **ACTION REQUIRED: Base image is on an archived/deleted repo.** `Containerfile` line 19 still references `ghcr.io/ublue-os/ucore-hci:stable-nvidia`. **`bsherman/ucore-hci` now returns HTTP 404** (was "archived" at bootstrap). `ublue-os/ucore-hci` GHCR container still rebuilt by the ublue-os org (`stable-nvidia-lts-20260511` published 2026-05-11), but the migration target remains `ghcr.io/ublue-os/ucore:stable-nvidia-lts`. Requires updating `renovate.json` `customManagers` regex `depName` and `image-versions.yml` `renovate: datasource=docker depName=` line. **Cannot be done by Renovate automerge.**

2. **ACTION REQUIRED: Pin cosign ≥ 3.0.6** wherever the project verifies signatures. Cosign GHSAs `GHSA-w6c6-c85g-mmv6`, `GHSA-wfqv-66vq-46rm`, `GHSA-whqx-f9j3-ch6m` all fixed in 3.0.6 / 2.6.3. Also `CVE-2026-22703` (Rekor entry not bound to artifact — verification bypass) fixed in 2.6.2 / 3.0.4. Verify the cosign binary baked into the image and the `automation/42-cosign-policy.sh` flow; also confirm CI workflows pass `--bundle` (v3 requires it where v2 made it optional). *(Note: `CVE-2026-31431` is the Linux kernel "Copy Fail" LPE, NOT a cosign CVE — the bootstrap pass had this conflated. Corrected in §6.5 and §7.1.)*

3. **ACTION REQUIRED: NVIDIA kmod pin — bump LTS floor.** `kmod-nvidia-open` must be ≥ **580.159.04** (LTS, released 2026-05-14, **bumped from 580.126.20**) or ≥ **595.71.05** (feature, 2026-04-28). Jan 2026 advisory `a_id/5747` covers CVE-2025-33219 (integer overflow → LPE/RCE), CVE-2025-23277, CVE-2025-23280 (UAF). No May 2026 bulletin yet. Update Renovate datasource floor accordingly.

4. **ACTION REQUIRED: Secure Boot 2023-CA shim refresh before 2026-06-26 (~6 weeks).** MS 2011 CA expires for new signatures on that date. **Fedora 44 final still ships `shim-16.1-5` (2021-key signed only).** Rawhide has `shim-16.1-6` (2023-key); track `bodhi.fedoraproject.org` for shim-16.1-6+ updates-testing → stable promotion. Pull Fedora's 2023-CA-signed shim into the MiOS image before then; apply Microsoft DBX update via `fwupdmgr` on target hardware. Already-running systems keep booting; only new installs onto firmware that has updated `db` would fail without the 2023-signed shim.

5. **ACTION REQUIRED: Migrate from `ublue-os/bootc-image-builder-action` to `osbuild/bootc-image-builder-action`** if CI uses the former (verify in `.github/workflows/` — still not inspected). Upstream maintenance-mode README in ublue-os repo points to the migration.

6. **ACTION REQUIRED: Fix `osautomation` → `osbuild` typo in `image-versions.yml`.** Confirmed `osautomation` GitHub user exists with zero public repos / no GHCR packages. The reference should be `ghcr.io/osbuild/image-builder-cli`. Trivial hand-fix.

7. **ACTION REQUIRED: Podman 6.0 GA in ~2 weeks (week of 2026-05-25).** Test Days closed 2026-05-15. Breaking removals: **BoltDB** (must finish v5.8 SQLite migration first), **slirp4netns** (→ Pasta), **cgroups v1**, **netavark iptables→nftables default**. Plus new `.artifact` Quadlet support. Pre-flight review of MiOS Quadlet units required before promoting Podman version label.

8. **ACTION REQUIRED: Migrate from `bootc-image-builder` to `image-builder-cli` (now possible, not forced).** `image-builder-cli` v64 (2026-05-13) shipped PR #510 "drop 'bootc is experimental'" — bootc subcommand is now GA. Canonical container: `ghcr.io/osbuild/image-builder-cli:latest`. Unified invocation pattern: `podman run --privileged ghcr.io/osbuild/image-builder-cli build --distro fedora-43 --bootc-ref ... --bootc-build-ref ...`. BIB remains an active separate repo; this is a "new option" not a forced migration.

9. **ACTION REQUIRED (informational, no MiOS-owned remediation): Linux kernel CVE cluster May 2026.** Five CVEs disclosed 2026-05-01 → 2026-05-08 hit the MiOS host kernel:
   - `CVE-2026-31431` — "Copy Fail" root LPE (Microsoft 2026-05-01).
   - `CVE-2026-43398` — AMDGPU OOM DoS (relevant via 9950X3D iGPU even when NVIDIA dGPU is primary).
   - `CVE-2026-43300` — DRM panel NULL deref.
   - `CVE-2026-43287` — DRM property-blob memcg accounting.
   - `CVE-2026-43284` — "Dirty Frag" via ESP/RxRPC.
   Track `ublue-os/ucore` issue #385; when ucore-hci LTS kernel rev lands, rebuild MiOS image.

---

## Priority topics for tomorrow's pass

Ordered by descending value. Rationale for ordering is captured under each.

### P0 — Re-verify all 9 ACTION REQUIRED items

Touch each upstream link to see if anything shifted in 24h. The Podman 6.0 GA and Secure Boot 2026-06-26 cutover are both tight deadlines worth daily checks.

- `ublue-os/ucore` issue #385 (kernel-bump for Copy Fail): https://github.com/ublue-os/ucore/issues/385
- `ublue-os/ucore` issue #362 (longterm-6.12 → 6.18): https://github.com/ublue-os/ucore/issues/362
- Cosign releases: https://github.com/sigstore/cosign/releases
- NVIDIA driver releases: https://github.com/NVIDIA/open-gpu-kernel-modules/releases
- NVIDIA security bulletins: https://nvidia.custhelp.com/app/answers/list/kw/security%20bulletin
- Fedora `shim-16.1-6` Bodhi promotion: https://bodhi.fedoraproject.org/updates/?packages=shim
- Podman 6.0 release: https://github.com/containers/podman/releases
- `image-builder-cli` releases (post v64): https://github.com/osbuild/image-builder-cli/releases

If any are resolved, **strike them from the ACTION REQUIRED list** in this file and note resolution in `ai-journal.md`.

### P1 — Podman 6.0 GA (target week of 2026-05-25)

*Why:* GA is the single biggest near-term scheduling risk. MiOS Quadlet units must be verified breakage-free against:
- BoltDB → SQLite (verify v5.8.x already-migrated state).
- slirp4netns → Pasta (rootless networking on Quadlet `.container` units).
- cgroups v1 removal (bootc Fedora is already on cgroupv2 — should be safe).
- netavark default iptables → nftables (host-side firewall integration).
- New `.artifact` Quadlet unit type (does MiOS want to use it for distributing the `mios` CLI?).

*Specific questions:*
- Has 6.0 tagged? GA notes posted?
- Any Quadlet schema breaking changes?
- Are `--cgroup-manager`, `--network-backend` defaults shifting?
- Is `podman migrate` automatic on first 6.0 boot?

*Anchor links:* https://github.com/containers/podman/releases, https://fedoraproject.org/wiki/Changes/Podman6, https://communityblog.fedoraproject.org/.

### P2 — Secure Boot 2023-CA shim in F44 stable

*Why:* 2026-06-26 cutover is ~6 weeks away. `shim-16.1-6` is in Rawhide but not F44 stable as of 2026-05-16. MiOS rebuilds onto firmware that has updated `db` will fail without the 2023-key shim.

*Specific questions:*
- Has `shim-16.1-6+` reached F44 stable (not just updates-testing)?
- Are there test-day reports of breakage on ucore base?
- Does Fedora's multi-signed shim auto-roll on bootc upgrade or require explicit `fwupdmgr` action?

*Anchor links:* https://bodhi.fedoraproject.org/updates/?packages=shim, https://discussion.fedoraproject.org/, https://fedoraproject.org/wiki/Test_Day:2026-01-12_Multi-signed_shim.

### P3 — `image-builder-cli` v64+ usage validation

*Why:* GA of the bootc subcommand opens a real consolidation path. Tomorrow: confirm the v64 invocation matches what MiOS would need.

*Specific questions:*
- What does the `image-builder-cli build` output schema look like for bootc? Does it produce the same `qcow2`/`raw`/`iso` formats as BIB at parity?
- Is BIB still strictly needed for any format BIB supports but image-builder-cli doesn't?
- Has osbuild published a deprecation timeline for BIB now that the bootc subcommand is GA?

*Anchor links:* https://github.com/osbuild/image-builder-cli/releases, https://github.com/osbuild/bootc-image-builder/issues, https://osbuild.org/blog/.

### P4 — ucore-hci kernel rev (issue #385) + LTS migration (issue #362)

*Why:* Direct blocker for landing the May 2026 kernel CVE cluster fixes. Once #385 lands, MiOS needs a rebuild. Once #362 lands (6.12 → 6.18), KVMFR DKMS rebuild must include the `vmalloc.h` + `MODULE_IMPORT_NS("DMA_BUF")` patches.

*Specific questions:*
- Has issue #385 closed? Which kernel rev landed?
- Has issue #362 closed? When does the 6.18 LTS image cut?

*Anchor links:* https://github.com/ublue-os/ucore/issues/385, https://github.com/ublue-os/ucore/issues/362.

### P5 — Composefs v1.1 + Linux kernel 6.18 / 6.19 overlayfs landing

*Why:* Userspace bottleneck per upstream. Track if any composefs-rs / bootc integration milestone lands in the weekly window.

*Specific questions:*
- Has composefs v1.1 been tagged?
- Has bootc removed the "experimental" framing on native composefs backend?

*Anchor links:* https://github.com/composefs/composefs/releases, https://bootc.dev/bootc/experimental-composefs.html.

### P6 — Looking Glass B8 RC + KVMFR kernel ≥6.13 patches upstreaming

*Why:* B7 was 2025-03-06. Cadence is ~2 years but the kernel ≥6.13 compat patches are accumulating in community fork-land. If gnif tags a B8 RC, the project should know within a day.

*Anchor links:* https://github.com/gnif/LookingGlass/releases, https://github.com/gnif/LookingGlass/commits/master/module.

### P7 — K3s v1.34.8 GA + gRPC-Go CVE-2026-33186 patch confirmation

*Why:* v1.34.8-rc1 was cut 2026-05-14. CVE-2026-33186 (gRPC-Go authz bypass) needs grpc-go v1.79.3+ — confirm whether the v1.34.8 GA notes call it out.

*Anchor links:* https://github.com/k3s-io/k3s/releases, https://github.com/advisories/GHSA-p77j-4mvh-x3m3.

### P8 — Fedora F45 schedule confirmation

*Why:* Wiki schedule page was 404 this pass. Need a clean source for F45 alpha/beta dates so MiOS rebuild scheduling can anchor against it.

*Specific questions:*
- F45 beta date confirmed (consensus suggests 2026-08-25)?
- Atomic Desktops in F45 confirmed using composefs+UKI sealed bootable container path?

*Anchor links:* https://fedoraproject.org/wiki/Releases/45/Schedule, https://discussion.fedoraproject.org/c/server/coreos/.

### P9 — Gamescope 3.17 tag + HDR fix commit `7d4e835` cherry-pick

*Why:* Issue #2037 reporter cites commit `7d4e835` as the HDR fix. Tomorrow: check if any 3.16.24+ point release picks up that commit, or if Valve cuts 3.17.

*Anchor link:* https://github.com/ValveSoftware/gamescope/releases.

### P10 — RTX 50-series passthrough watch (low priority)

*Why:* Project's 4090 is unaffected. Useful only as a multi-month signal.

*Anchor links:* https://forum.level1techs.com/t/do-your-rtx-5090-or-general-rtx-50-series-has-reset-bug-in-vm-passthrough/228549, https://www.cloudrift.ai/blog/bug-bounty-nvidia-reset-bug.

---

## Upstream releases + CVE feeds to monitor

| Source | What to check |
| ------ | ------------- |
| https://github.com/bootc-dev/bootc/releases | new tags, kargs.d format changes |
| https://github.com/osbuild/bootc-image-builder | new container tags |
| https://github.com/osbuild/image-builder-cli/releases | post-v64 |
| https://github.com/ublue-os/ucore | NVIDIA driver pin, issue #385, issue #362 |
| https://github.com/composefs/composefs/releases | v1.1 cut |
| https://github.com/ostreedev/ostree/releases | new tags |
| https://github.com/containers/podman/releases | **v6.0 GA — TIGHT WATCH** |
| https://github.com/k3s-io/k3s/releases | v1.34.8 GA, v1.35.5 GA |
| https://github.com/etcd-io/etcd/releases | post-3.5.30 |
| https://ceph.io/en/news/blog/ | Tentacle patch releases, Squid security bulletins |
| https://github.com/crowdsecurity/crowdsec/releases | post-1.7.6 |
| https://github.com/sigstore/cosign/releases | post-3.0.6 |
| https://nvidia.custhelp.com/app/answers/list/kw/security%20bulletin | May 2026 bulletin (if any) |
| https://github.com/NVIDIA/open-gpu-kernel-modules/releases | post-580.159.04 / post-595.71.05 |
| https://github.com/NVIDIA/nvidia-container-toolkit/releases | post-1.19.0 |
| https://github.com/gnif/LookingGlass/releases | B8 |
| https://www.qemu.org/blog/ | post-10.2.0 |
| https://libvirt.org/news.html | post-12.1.0 |
| https://docs.mesa3d.org/relnotes/ | post-25.3.4 |
| https://release.gnome.org/ | GNOME 51 alpha (planned 2026-06-27) |
| https://github.com/microsoft/WSL/releases | post-2.7.5 |
| https://github.com/systemd/systemd/releases | post-260 |
| https://github.com/renovatebot/renovate/releases | post-43.181.0 |
| https://bodhi.fedoraproject.org/updates/?packages=shim | shim-16.1-6+ F44 promotion |
| https://github.com/bootc-dev/bootc/issues/899 | `/etc/bootc/kargs.d` merge RFE |
| https://github.com/bootc-dev/bootc/issues/946 | rollback-after-switch sharp edge |
| https://github.com/NVIDIA/nvidia-container-toolkit/issues/1735 | nvidia-cdi-refresh ordering |
| https://forum.level1techs.com/t/do-your-rtx-5090-or-general-rtx-50-series-has-reset-bug-in-vm-passthrough/228549 | RTX 50 reset bug |
| https://access.redhat.com/security/cve/cve-2026-31431 | Copy Fail tracking |

---

## Follow-up questions raised (resolved + unresolved)

**Resolved this pass:**
1. ~~What is `ghcr.io/osautomation/image-builder-cli`?~~ **Resolved: typo for `osbuild`.** `osautomation` GitHub user has zero public repos / no GHCR packages.

**Carried forward (still unresolved — out of research-only scope):**
2. **Does any GitHub workflow (`.github/workflows/`) still call `ublue-os/bootc-image-builder-action`?** Migrate to `osbuild/bootc-image-builder-action` if so. Did not inspect workflows.
3. **Where does `automation/42-cosign-policy.sh` get the cosign binary, and is it pinned to a digest?** Need to confirm we're past 3.0.6.
4. **Are MiOS SELinux site modules going into `/etc/selinux/targeted/active/modules/400/` (persists) or `/usr/lib/selinux/` (gets wiped on bootc update)?** The latter is wrong on composefs/bootc.
5. **Does the project run K3s in HA mode or single-node sqlite mode?** Affects etcd-migration urgency. Inspect `automation/13-ceph-k3s.sh` next pass.
6. **Has `automation/52-bake-kvmfr.sh` been verified to sign at image-build time, not first-boot?** First-boot signing assumes mutable rootfs. Once ucore-hci LTS image bumps to 6.18, this script must also apply the `vmalloc.h` / `MODULE_IMPORT_NS("DMA_BUF")` patches.
7. **Is fapolicyd's trust DB being rebuilt at image-build time (`fapolicyd-cli --update`) or relying on the dnf plugin?** On bootc the plugin is a no-op at runtime.
8. **GNOME 50 in `ucore-hci:stable-nvidia` yet?** If yes, remove any X11-session fallback in the MiOS profile.

**New this pass:**
9. **Does MiOS use AMD iGPU at all?** CVE-2026-43398 (AMDGPU OOM DoS) hits the 9950X3D iGPU unless the `amdgpu` driver is blacklisted. If MiOS doesn't actually use the iGPU, a blacklist is a defense-in-depth move.
10. **Does the project's `mios-sysext-pack.sh` consume systemd 260's new central config (`/etc/systemd/systemd-sysext.conf`)?** Bootstrap doc assumed 259 was the latest; 260 is actually stable. Image-policy / mutability configurable centrally per the new config file may simplify the script.

---

## Priority-order rationale

P0 (reverify) first — same reasoning as bootstrap pass: a 24h-old ACTION REQUIRED that's resolved is wasted work tomorrow. **P1 (Podman 6.0)** and **P2 (Secure Boot)** are calendar-tight: Podman GA is 9 days out, Secure Boot cutover is 41 days out — both directly affect MiOS rebuild scheduling. **P3 (image-builder-cli GA)** is a new strategic option that just opened; understanding the actual command surface matters before committing. **P4 (ucore-hci issues #385 + #362)** gates the kernel CVE-cluster remediation. **P5 (composefs)** is the long-horizon storage substrate question. P6–P10 are slower-moving or lower-impact monthly checks.

Anything not on this list can be skipped tomorrow unless an upstream release explicitly demands inclusion. **Tomorrow's run should overwrite this file with its own next-day agenda.**
