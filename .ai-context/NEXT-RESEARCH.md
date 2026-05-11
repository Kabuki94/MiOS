# NEXT-RESEARCH — agenda for next scheduled-research pass

> Written by `scheduled-research-daily` on 2026-05-11 (UTC) at the end of the bootstrap pass. Tomorrow's run should start here.

---

## ACTION REQUIRED items (carry forward until resolved)

These are upstream signals that imply a build-breaking or security change to the project. **The research agent never applies these.** They are surfaced here for human review and follow-up.

1. **ACTION REQUIRED: Base image is on an archived repo.** `Containerfile` line 19 still references `ghcr.io/ublue-os/ucore-hci:stable-nvidia`. The `bsherman/ucore-hci` upstream is **archived**; dev consolidated to `ublue-os/ucore`. Recommended target: `ghcr.io/ublue-os/ucore:stable-nvidia-lts` (580 LTS pre-signed `kmod-nvidia-open`). Also requires updating `renovate.json` `customManagers` regex `depName` and `image-versions.yml` `renovate: datasource=docker depName=` line. Cannot be done by Renovate automerge.

2. **ACTION REQUIRED: Pin cosign ≥ 3.0.6** wherever the project verifies signatures. CVEs `CVE-2026-22703` (Rekor entry not bound to artifact — verification bypass) and `CVE-2026-31431` (`verify-blob-attestation` false-OK). Verify the cosign binary baked into the image and the `automation/42-cosign-policy.sh` flow; also confirm CI workflows pass `--bundle` (v3 requires it where v2 made it optional).

3. **ACTION REQUIRED: NVIDIA kmod pin.** `kmod-nvidia-open` must be ≥ **580.126.20** (LTS, preferred) or ≥ **595.71.05** (feature). January 2026 advisory: CVE-2025-33219 (integer overflow → LPE/RCE), CVE-2025-23277, CVE-2025-23280 (UAF). Source: NVIDIA security bulletin, Jan 2026.

4. **ACTION REQUIRED: Secure Boot 2023-CA shim refresh before 2026-06-26.** MS 2011 CA expires for new signatures on that date. Pull Fedora's 2023-CA-signed shim into the MiOS image before then; apply Microsoft DBX update via `fwupdmgr` on target hardware. Already-running systems keep booting; only new installs onto firmware that has updated `db` would fail without the 2023-signed shim.

5. **ACTION REQUIRED: Migrate from `ublue-os/bootc-image-builder-action` to `osbuild/bootc-image-builder-action`** if CI uses the former (verify in `.github/workflows/` — not inspected this pass).

6. **NOTE (not action required, but verify):** `image-versions.yml` references `ghcr.io/osautomation/image-builder-cli` with `0000…0000` digest. No `osautomation` org exists upstream. Likely a typo for `osbuild/image-builder-cli` or an internal fork — confirm with project maintainer.

---

## Priority topics for tomorrow's pass

Ordered by descending value. Rationale for ordering is captured under each.

### P0 — Verify the ACTION REQUIRED items haven't been resolved

Before re-researching deeply, hit each upstream link below to see if anything shifted in 24h:
- NVIDIA security bulletin: https://nvidia.custhelp.com/app/answers/detail/a_id/5747/
- cosign releases: https://github.com/sigstore/cosign/releases
- ucore-hci → ublue-os/ucore migration tracker: https://github.com/ublue-os/ucore/issues
- Fedora multi-signed shim status: https://fedoraproject.org/wiki/Test_Day:2026-01-12_Multi-signed_shim
- bootc-image-builder action mirror: https://github.com/osbuild/bootc-image-builder-action

If any are resolved, **strike them from the ACTION REQUIRED list** in this file and note resolution in `ai-journal.md`.

### P1 — BIB ↔ image-builder-cli unification

*Why:* Project's `image-versions.yml` tracks both. The unification will affect Renovate datasource entries and Containerfile build commands. Targeted 2026 H2 by upstream. Worth tracking the consolidation RFC/milestone monthly.

*Specific questions:*
- Is there a pinned milestone or RFC number?
- Does `osbuild/image-builder-cli` (or wherever `osautomation` resolves to) have a `bootc` subcommand yet?
- What does the unified disk-image build command look like?

*Anchor links:* https://github.com/osbuild/image-builder-cli, https://github.com/osbuild/bootc-image-builder, https://osbuild.org/.

### P2 — composefs v1.1 timing and kernel-overlayfs landings

*Why:* bootc's native composefs backend is gated on overlayfs kernel changes. The project uses composefs implicitly via ostree/bootc; a v1.1 cut + kernel landing would let the project consider opting into native composefs GA. Currently still labelled experimental.

*Specific questions:*
- Has composefs v1.1 been tagged?
- What kernel version lands the required overlayfs changes?
- Any breaking on-disk format change between 1.0.x and 1.1?

*Anchor links:* https://github.com/composefs/composefs/releases, https://bootc.dev/bootc/experimental-composefs.html.

### P3 — Podman 6.0 release date and bootc-relevant changes

*Why:* BoltDB→SQLite migration in 5.8.0 is a required intermediate hop before v6.0. Knowing the v6.0 release date affects upgrade scheduling and which Podman version MiOS bakes in.

*Specific questions:*
- Has v6.0 been tagged or has a release candidate?
- Any Quadlet schema breaking changes?
- Status of `.image` and `.artifact` Quadlet unit types in v6.0?

*Anchor links:* https://github.com/containers/podman/releases, https://github.com/containers/podman/blob/main/RELEASE_NOTES.md.

### P4 — Looking Glass B8 and kvmfr DKMS+SecureBoot story

*Why:* B7 was March 2025; cadence is ~2 years but a B8 RC could land any month. KVMFR remains DKMS-only — if B8 changes the module signing flow that affects the Containerfile bake step (`automation/52-bake-kvmfr.sh`).

*Specific questions:*
- B8 RC tagged?
- Any move toward in-tree kvmfr submission?
- Wayland client packaging changes?

*Anchor links:* https://github.com/gnif/LookingGlass, https://looking-glass.io/.

### P5 — RTX 50-series passthrough state

*Why:* Project targets RTX 4090 today, but Blackwell is the consumer GPU successor. CloudRift bounty is open ($1000). Track whether NVIDIA ships a patch, whether vfio-pci kernel side gets the IOMMU 1:1 mapping workaround, and the `iommu=pt` vs `iommu=on` decision matrix.

*Specific questions:*
- NVIDIA driver ≥ 600 series and FLR reset bug?
- Kernel 6.18+ patches for IOMMU 1:1?
- Confirm RTX 4090 still works on `iommu=pt` (project's current kargs.d setting).

*Anchor links:* https://forum.level1techs.com/t/do-your-rtx-5090-or-general-rtx-50-series-has-reset-bug-in-vm-passthrough/228549, https://www.cloudrift.ai/blog/bug-bounty-nvidia-reset-bug.

### P6 — GNOME 51 alpha (planned 2026-06-27)

*Why:* If MiOS bumps `ucore-hci` (or its replacement) past GNOME 50, an early GNOME 51 alpha lets us flag regressions before they hit ucore stable. Wayland-only is now baseline so the X11 fallback question is settled.

*Specific questions:*
- GNOME 51 alpha tagged?
- Any new Wayland protocol requirements (explicit-sync v2?)?
- NVIDIA driver minimum bump?

*Anchor links:* https://release.gnome.org/calendar/, https://release.gnome.org/.

### P7 — Fedora 45 branching & bootc CI matrix

*Why:* F45 branched from rawhide 2026-02-06. Watch the bootc CI matrix to forecast when MiOS should test against F45 base images.

*Specific questions:*
- F45 alpha/beta dates?
- Any planned bootc-format-breaking changes in F45?

*Anchor links:* https://fedoraproject.org/wiki/Releases/45/Schedule (verify it exists), https://discussion.fedoraproject.org/c/server/coreos/.

### P8 — Gamescope 3.17 tag

*Why:* HDR regression on Fedora 43 + GNOME 49 + NVIDIA 595 + KDE Plasma 6.5.3 is unfixed in the 3.16.17 tag. Project does not depend on HDR-on-Wayland today, but if the gamescope session is exposed, the 3.17 tag is the unblocker.

*Anchor link:* https://github.com/ValveSoftware/gamescope/releases.

### P9 — etcd 3.5.26 vs 3.6.7 migration window for K3s

*Why:* Project uses K3s. If it moves from K3s v1.33 to v1.34 in any image rev, the etcd 3.5→3.6 hop must transit through v3.5.26 first. Single-node sqlite users are unaffected; HA cluster paths are.

*Specific questions:*
- Is the project running K3s in HA mode? (Inspect `automation/13-ceph-k3s.sh` next pass.)
- K3s v1.35 line cadence?

*Anchor links:* https://docs.k3s.io/release-notes/v1.34.X, https://github.com/k3s-io/k3s/releases.

### P10 — systemd 260 + sysext-on-bootc

*Why:* systemd 259 stabilized sysext config; 260 is in development. bootc + sysext (sysexts as separate OCI tags managed in lockstep) is still WIP. If it goes production-blessed, MiOS's `mios-sysext-pack.sh` flow may want to switch from baked-in to lockstep.

*Anchor links:* https://github.com/systemd/systemd/releases, https://travier.github.io/fedora-sysexts/.

---

## Upstream releases + CVE feeds to monitor

| Source | What to check |
| ------ | ------------- |
| https://github.com/bootc-dev/bootc/releases | new tags, kargs.d format changes |
| https://github.com/osbuild/bootc-image-builder | new container tags |
| https://github.com/ublue-os/ucore | NVIDIA driver pin in `stable-nvidia` / `stable-nvidia-lts` |
| https://github.com/composefs/composefs/releases | v1.1 cut |
| https://github.com/ostreedev/ostree/releases | new tags |
| https://github.com/containers/podman/releases | v6.0 |
| https://github.com/k3s-io/k3s/releases | v1.34, v1.35 |
| https://ceph.io/en/news/blog/ | Tentacle patch releases, Squid security bulletins |
| https://github.com/crowdsecurity/crowdsec/releases | new agent, hub additions |
| https://github.com/sigstore/cosign/releases | post-3.0.6 |
| https://nvidia.custhelp.com/app/answers/list/kw/security%20bulletin | quarterly |
| https://github.com/NVIDIA/nvidia-container-toolkit/releases | post-1.19.0 |
| https://github.com/gnif/LookingGlass/releases | B8 |
| https://www.qemu.org/blog/ | post-10.2.0 |
| https://libvirt.org/news.html | post-12.1.0 |
| https://docs.mesa3d.org/relnotes/ | post-25.3.4 |
| https://release.gnome.org/ | GNOME 51 alpha |
| https://github.com/microsoft/WSL/releases | post-2.7.3 |
| https://github.com/systemd/systemd/releases | v260 |
| https://github.com/renovatebot/renovate/releases | post-43.173.0 |
| https://github.com/bootc-dev/bootc/issues/899 | `/etc/bootc/kargs.d` merge RFE |
| https://github.com/bootc-dev/bootc/issues/946 | rollback-after-switch sharp edge |
| https://github.com/NVIDIA/nvidia-container-toolkit/issues/1735 | nvidia-cdi-refresh ordering |
| https://forum.level1techs.com/t/do-your-rtx-5090-or-general-rtx-50-series-has-reset-bug-in-vm-passthrough/228549 | RTX 50 reset bug |

---

## Follow-up questions raised today

1. **What is `ghcr.io/osautomation/image-builder-cli`?** Internal fork, typo, or a real upstream we missed? Resolve before next BIB-related update.
2. **Does any GitHub workflow (`.github/workflows/`) still call `ublue-os/bootc-image-builder-action`?** Migrate to `osbuild/bootc-image-builder-action` if so. Did not inspect workflows this pass.
3. **Where does `automation/42-cosign-policy.sh` get the cosign binary, and is it pinned to a digest?** Need to confirm we're past 3.0.6.
4. **Are MiOS SELinux site modules going into `/etc/selinux/targeted/active/modules/400/` (persists) or `/usr/lib/selinux/` (gets wiped on bootc update)?** The latter is wrong on composefs/bootc.
5. **Does the project run K3s in HA mode or single-node sqlite mode?** Affects etcd-migration urgency. Inspect `automation/13-ceph-k3s.sh` next pass.
6. **Has `automation/52-bake-kvmfr.sh` been verified to sign at image-build time, not first-boot?** First-boot signing assumes mutable rootfs.
7. **Is fapolicyd's trust DB being rebuilt at image-build time (`fapolicyd-cli --update`) or relying on the dnf plugin?** On bootc the plugin is a no-op at runtime.
8. **GNOME 50 in `ucore-hci:stable-nvidia` yet?** If yes, remove any X11-session fallback in the MiOS profile.

---

## Priority-order rationale

P0 reverification first because a 24h-old ACTION REQUIRED that's been resolved would be wasted effort tomorrow. P1–P3 (BIB/composefs/Podman) chosen next because they affect the build-deploy lifecycle directly — biggest blast radius if upstream shifts. P4–P5 (Looking Glass / RTX 50) chosen for the project's GPU-passthrough identity. P6–P8 are time-locked to specific calendar dates we should not miss. P9–P10 are slower-moving but worth a monthly check.

Anything not on this list can be skipped tomorrow unless an upstream release explicitly demands inclusion. **Tomorrow's run should overwrite this file with its own next-day agenda.**
