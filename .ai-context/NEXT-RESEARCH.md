# NEXT-RESEARCH — agenda for next scheduled-research pass

> Written by `scheduled-research-daily` on 2026-05-20 (UTC). Tomorrow's run should start here.

---

## ACTION REQUIRED items (carry forward until resolved)

These are upstream signals that imply a build-breaking or security change to the project. **The research agent never applies these.** They are surfaced here for human review and follow-up.

1. **ACTION REQUIRED (ESCALATED — now a 3-CVE local-root cluster, base image unpatched): kernel LPE exposure.** The MiOS LTS base image (`stable-nvidia-lts-20260511`) is built before any of the relevant kernel fixes landed and the upstream daily-bake is stalled (13 days), so the base is now behind on multiple named local-root vectors:
   - **`CVE-2026-31431` "Copy Fail"** — `algif_aead` AF_ALG root LPE, CVSS 7.8, **on CISA KEV, federal deadline 2026-05-15 already 5 days past.** Fixed upstream 6.18.22 / 6.19.12 / 7.0; **Red Hat fixes now expedited/available (RHSB-2026-002).**
   - **`CVE-2026-31635` "DirtyDecrypt" (NEW 2026-05-20)** — RxGK LPE, CVSS 7.5, **only triggers on `CONFIG_RXGK` kernels (Fedora/Arch/openSUSE Tumbleweed)** → applies to the MiOS Fedora base. Fix merged upstream 2026-04-25; public PoC 2026-05-18. Container/pod-escape pathway noted.
   - **`CVE-2026-46333` "ssh-keysign-pwn" (NEW 2026-05-20)** — ptrace exit-race info-disclosure → LPE (steals SSH host keys + `/etc/shadow`). Fixed in 7.0.8 / 6.18.31 / 6.12.89 / 6.6.139 / 6.1.173.
   - Plus the prior AMDGPU/DRM cluster + "Dirty Frag" (43284) + "Fragnesia" (46300).
   **Remediation path is `ublue-os/ucore` PR #392 (F43→F44 base) — still open, unmerged, unreviewed.** Until it merges and a new image is cut, MiOS is exposed. **Defense-in-depth the owner may consider pre-merge:** `modprobe.blacklist=algif_aead algif_skcipher algif_hash algif_rng` neutralizes the Copy Fail AF_ALG primitive directly (if MiOS doesn't use AF_ALG); `kernel.dmesg_restrict=1`; for DirtyDecrypt, RxGK is an AFS/rxrpc auth surface MiOS almost certainly doesn't use — blacklisting `rxrpc`/disabling `CONFIG_RXGK` paths would remove it, but that requires base-kernel config the project doesn't own.

2. **ACTION REQUIRED: Base image is on an archived/deleted repo + cadence stalled 9 days + upstream main idle 13 days.** `Containerfile` line 19 still references `ghcr.io/ublue-os/ucore-hci:stable-nvidia`. `bsherman/ucore-hci` returns HTTP 404. `ublue-os/ucore-hci` GHCR latest tag is still `stable-nvidia-lts-20260511` (9 days old). `ublue-os/ucore` main has had zero commits since 2026-05-07 (13 days idle). Migration target remains `ghcr.io/ublue-os/ucore:stable-nvidia-lts`. Requires updating `renovate.json` `customManagers` regex `depName` and `image-versions.yml` `renovate: datasource=docker depName=` line. **Cannot be done by Renovate automerge.**

3. **ACTION REQUIRED: Pin cosign ≥ 3.0.6** wherever the project verifies signatures. Cosign GHSAs `GHSA-w6c6-c85g-mmv6` (now CVE-2026-39395, CVSS 4.3), `GHSA-wfqv-66vq-46rm`, `GHSA-whqx-f9j3-ch6m` all fixed in 3.0.6 / 2.6.3. Also `CVE-2026-22703` (Rekor entry not bound to artifact — verification bypass) fixed in 2.6.2 / 3.0.4. Verify the cosign binary baked into the image and the `automation/42-cosign-policy.sh` flow; also confirm CI workflows pass `--bundle` (v3 requires it where v2 made it optional). cosign latest still v3.0.6 (2026-04-06) — no newer release this window.

4. **ACTION REQUIRED (downgraded — bulletin published, pins already satisfy): NVIDIA kmod pin.** The **NVIDIA May 2026 bulletin (a_id/5821, 13 CVEs, top `CVE-2026-24187` CVSS 8.8 Linux UAF) is now published.** Linux fix floors: R595 = 595.71.05, R580 RTX/Quadro/NVS = 580.159.03, R580 GeForce = 580.126.09, R570 = 570.211.01, R535 = 535.309.01. **The project's pins (LTS 580.159.04 ≥ 580.159.03; production-feature 595.71.05 = fix) already satisfy this — no bump forced.** Action remaining: (a) confirm the GHCR `ucore-hci` image actually bakes ≥580.159.03 (it should — lts-20260511 ≈ 580.159.04); (b) if pinning the feature branch, keep distinguishing 595.71.05 production-feature from 595.44.08 developer-beta. Jan 2026 advisory a_id/5747 (CVE-2025-33219, -23277, -23280) still applies as the older floor.

5. **ACTION REQUIRED: Secure Boot 2023-CA shim refresh before 2026-06-26 (~37 days).** MS 2011 CA expires for new signatures on that date. **Fedora 44 stable + updates + updates-testing all still ship `shim-16.1-5` (2021-key signed only)** — verified 2026-05-20. `shim-16.1-6` (2023-key) remains rawhide-only. **All of bodhi/koji/src.fedoraproject.org AND now `dl.fedoraproject.org` are Anubis-gated** — the working package-listing path is now `https://mirrors.kernel.org/fedora/releases/44/Everything/x86_64/os/Packages/s/` (+ `.../updates/` + `.../updates-testing/`). Hard checkpoint: 2026-06-05 — if shim-16.1-6 still has not landed in F44 stable by then, MiOS needs a fallback. Apply Microsoft DBX update via `fwupdmgr` on target hardware.

6. **ACTION REQUIRED: Migrate from `ublue-os/bootc-image-builder-action` to `osbuild/bootc-image-builder-action`** if CI uses the former (verify in `.github/workflows/` — still not inspected; out of research-only scope). The osbuild fork is actively maintained; the ublue-os fork is maintenance-mode pointing to the migration.

7. **ACTION REQUIRED: Fix `osautomation` → `osbuild` typo in `image-versions.yml`.** Confirmed `osautomation` GitHub user has zero public repos / no GHCR packages. Reference should be `ghcr.io/osbuild/image-builder-cli`. Trivial hand-fix.

8. **ACTION REQUIRED (F45-paced, ~5 months out): Podman 6.0 GA slipped to Fedora 45.** No upstream 6.0 RC has been cut (latest stable still v5.8.2). Pre-flight Quadlet review still required (BoltDB → SQLite, slirp4netns → Pasta, cgroups v1 removal, netavark default iptables → nftables) but is F45-paced (Oct 2026).

9. **ACTION REQUIRED: Migrate from `bootc-image-builder` to `image-builder-cli` (now possible, partial parity).** `image-builder-cli` v64 (2026-05-13) GA-ed the bootc subcommand. Canonical container: `ghcr.io/osbuild/image-builder-cli:latest`. **However, public docs only enumerate qcow2 + bootc-installer ISO patterns** — raw/ami/vmdk/vhd/gce not documented. BIB still has the wider format matrix. Viable for qcow2/ISO workflows only until full parity. (Issue #506 = upstream tracker for composefs+UKI sealed-image bootc backend; still open, last updated 2026-04-29.)

---

## Priority topics for tomorrow's pass

Ordered by descending value. Rationale captured under each.

### P0 — Re-verify all 9 ACTION REQUIRED items

Touch each upstream link to see if anything shifted in 24h. **Tightest deadlines: (a) PR #392 merge status — gates the only kernel-CVE remediation path for a now-3-CVE local-root cluster; (b) Secure Boot 2026-06-26 cutover at ~37 days.** Re-check ucore main / `ucore-hci` daily-bake cadence — if main resumes activity or a new tag lands, actions #1 and #2 unblock meaningfully.

- `ublue-os/ucore` PR #392 (F43→F44): https://github.com/ublue-os/ucore/pull/392 — **TIGHT WATCH, top-priority**
- `ublue-os/ucore` issue #385 (kernel-bump for Copy Fail): https://github.com/ublue-os/ucore/issues/385
- `ublue-os/ucore` main commit feed (idle 13 days): https://github.com/ublue-os/ucore/commits/main
- ucore-hci GHCR tags: https://github.com/ublue-os/ucore/pkgs/container/ucore-hci
- Cosign releases: https://github.com/sigstore/cosign/releases
- NVIDIA driver releases: https://github.com/NVIDIA/open-gpu-kernel-modules/releases
- Fedora shim-16.1-6 F44 promotion (NEW alternate path): https://mirrors.kernel.org/fedora/releases/44/Everything/x86_64/os/Packages/s/ (+ updates / updates-testing)
- Podman 6.0 release: https://github.com/containers/podman/releases
- `image-builder-cli` releases (post v64): https://github.com/osbuild/image-builder-cli/releases

If any are resolved, **strike them from the ACTION REQUIRED list** in this file and note resolution in `ai-journal.md`.

### P1 — PR #392 merge status + kernel package version in any new ucore-hci tag

*Why:* Still THE most important watch item — the only visible remediation path for the kernel local-root cluster (Copy Fail + DirtyDecrypt + ssh-keysign-pwn), which now spans 3 named CVEs with public PoCs. PR has been static since 2026-05-17 (force-push `cce1716`); upstream main idle 13 days.

*Specific questions:*
- Has PR #392 merged? Has issue #385 closed?
- If merged, has a new `stable-nvidia-lts-YYYYMMDD` tag landed in GHCR?
- Skopeo/oci-inspect the new image: what kernel package version does it bake? (Must be ≥ 6.18.22 / 6.19.12 / 7.0 for Copy Fail; ≥ 6.18.31 / 6.12.89 for ssh-keysign-pwn; DirtyDecrypt fix merged 2026-04-25 so any kernel built after that carries it.)
- Any new ucore main commits at all?

*Anchor links:* https://github.com/ublue-os/ucore/pull/392, https://github.com/ublue-os/ucore/pkgs/container/ucore-hci, https://github.com/ublue-os/ucore/issues/385.

### P2 — Secure Boot shim-16.1-6 in F44 stable (via mirrors.kernel.org)

*Why:* 2026-06-26 cutover is ~37 days. Tightest hard-calendar deadline. dl.fedoraproject.org is now Anubis-gated; the new working path is the mirrors.kernel.org tree.

*Specific questions:*
- Fetch `https://mirrors.kernel.org/fedora/releases/44/Everything/x86_64/os/Packages/s/` and the `.../updates/` + `.../updates-testing/` trees — grep for `shim-`; is 16.1-6 present anywhere in F44 yet?
- Does Fedora's multi-signed shim auto-roll on bootc upgrade or require explicit `fwupdmgr` action?
- Hard checkpoint 2026-06-05 looming — flag escalation if still 16.1-5 by then.

*Anchor links:* https://mirrors.kernel.org/fedora/releases/44/Everything/x86_64/os/Packages/s/, https://fedoraproject.org/wiki/Test_Day:2026-01-12_Multi-signed_shim.

### P3 — K3s v1.34.8 / v1.35.5 / v1.36.1 GA + CVE-2026-33186 callout

*Why:* RCs cut 2026-05-14 still pre-release at 6 days. CVE-2026-33186 (gRPC-Go authz bypass, CVSS 9.1, fixed grpc-go v1.79.3) still not explicitly called out in any K3s RC/GA notes. K3s GA notes need to confirm grpc-go ≥ 1.79.3 is bundled.

*Specific questions:*
- Has any of v1.34.8 / v1.35.5 / v1.36.1 GA shipped?
- Do GA notes mention grpc-go ≥ 1.79.3 / CVE-2026-33186? (v1.36.0 GA only cited CVE-2025-54410 docker/docker.)
- If not, infer grpc-go version from Go 1.25.9 vendored deps in the RC branch `go.mod`.

*Anchor links:* https://github.com/k3s-io/k3s/releases, https://github.com/advisories/GHSA-p77j-4mvh-x3m3.

### P4 — Pacemaker 3.0.2 final ship

*Why:* rc2 was 2026-05-11; 9 days in. rc1→rc2 gap was ~17 days; projected final ~2026-05-28. Mature watch, "expected within days."

*Anchor link:* https://github.com/ClusterLabs/pacemaker/releases.

### P5 — GNOME 50.2 ship (2026-05-23) + DirtyDecrypt Fedora kernel erratum

*Why:* Two near-term confirmations. (a) GNOME 50.2 stable point release is scheduled 2026-05-23 — confirm it ships and whether it carries any Wayland/NVIDIA-explicit-sync/HDR fix relevant to MiOS GRD/Gamescope. (b) `CVE-2026-31635` "DirtyDecrypt" needs a Fedora-specific kernel erratum confirmation — the fix is upstream (2026-04-25) but verify which Fedora kernel build first carries it, to inform whether the eventual F44-base bump actually closes it.

*Anchor links:* https://release.gnome.org/calendar/, https://bodhi.fedoraproject.org/updates/?packages=kernel (Anubis-gated — try mirrors.kernel.org changelog or kernel.org for the fixed version), https://www.kernel.org/.

### P6 — Podman 6.0 RC tag watch (F45-paced)

*Why:* GA slip relieves immediate pressure, but an RC tag will still drop and Quadlet schema deltas remain undocumented. When an RC lands, the project gets concrete diff signal.

*Anchor links:* https://github.com/containers/podman/releases, https://fedoraproject.org/wiki/Changes/Podman6.

### P7 — `image-builder-cli` v65+ + parity progress

*Why:* bootc subcommand is GA but format matrix is narrower than BIB. Check for v65, new format support in docs, BIB deprecation timeline, issue #506 (composefs+UKI sealed-image backend). osbuild.org/blog still 404 — retry.

*Anchor links:* https://github.com/osbuild/image-builder-cli/releases, https://github.com/osbuild/image-builder-cli/issues/506, https://github.com/osbuild/bootc-image-builder/issues, https://osbuild.org/blog/.

### P8 — composefs v1.1 tag + bootc native-backend GA

*Why:* `main` is active again (PR #436 merged 2026-05-19) but still no tag in 16.5 months; bootc still flags the native composefs backend "experimental." If composefs v1.1 cuts and bootc drops the experimental framing, that's a significant on-disk-format event for MiOS, and gates the F45 Atomic Desktops sealed-image direction.

*Anchor links:* https://github.com/composefs/composefs/releases, https://github.com/composefs/composefs/commits/main, https://bootc.dev/bootc/experimental-composefs.html.

### P9 — Looking Glass cadence (B7 stalled, master idle 4+ months)

*Why:* Master has zero commits since 2026-01-17. If cadence resumes, indicates active development; if not, the KVMFR kernel-≥6.13 patches must be carried by the project itself once the base bumps to 6.18.

*Anchor links:* https://github.com/gnif/LookingGlass/commits/master, https://github.com/gnif/LookingGlass/commits/master/module.

### P10 — Gamescope 3.17 tag + HDR fix commit `7d4e835` (low priority)

*Why:* Long-horizon. HDR fix in master not in any tag; #2000/#2018/#2037 open, no maintainer ack. Check if any 3.16.24+ point release picks up `7d4e835`, or if Valve cuts 3.17.

*Anchor links:* https://github.com/ValveSoftware/gamescope/tags, https://github.com/ValveSoftware/gamescope/issues/2037.

---

## Upstream releases + CVE feeds to monitor

| Source | What to check |
| ------ | ------------- |
| https://github.com/ublue-os/ucore/pull/392 | **PR #392 merge status — TIGHTEST WATCH** |
| https://github.com/ublue-os/ucore/commits/main | upstream activity (idle 13 days) |
| https://github.com/ublue-os/ucore/pkgs/container/ucore-hci | daily-build cadence (9 days stale) — TIGHT WATCH |
| https://github.com/bootc-dev/bootc/releases | post-v1.15.2 |
| https://github.com/osbuild/bootc-image-builder | new container tags |
| https://github.com/osbuild/image-builder-cli/releases | post-v64 |
| https://github.com/osbuild/image-builder-cli/issues/506 | composefs+UKI sealed-image work |
| https://github.com/composefs/composefs/commits/main | post-PR #436 (active again); v1.1 tag |
| https://github.com/ostreedev/ostree/releases | post-v2026.1 |
| https://github.com/containers/podman/releases | v6.0 RC tag (none yet) |
| https://github.com/k3s-io/k3s/releases | **v1.34.8 / v1.35.5 / v1.36.1 GA — TIGHT WATCH** + grpc-go callout |
| https://github.com/etcd-io/etcd/releases | post-3.7.0-beta.0 (pre-GA); stable 3.6.x/3.5.x |
| https://ceph.io/en/news/blog/ | Tentacle patch releases, Squid security bulletins |
| https://github.com/ClusterLabs/pacemaker/releases | **3.0.2 final — TIGHT WATCH** (rc2 9 days old) |
| https://github.com/crowdsecurity/crowdsec/releases | post-1.7.8 |
| https://github.com/linux-application-whitelisting/fapolicyd/releases | post-1.4.5 |
| https://github.com/sigstore/cosign/releases | post-3.0.6 |
| https://nvidia.custhelp.com/app/answers/detail/a_id/5821 | **May 2026 bulletin (NEW, 403/Anubis-gated — use GamingOnLinux mirror)** |
| https://github.com/NVIDIA/open-gpu-kernel-modules/releases | post-580.159.04 / 595.71.05 / 595.44.08 |
| https://github.com/NVIDIA/nvidia-container-toolkit/releases | post-1.19.0 |
| https://github.com/gnif/LookingGlass/commits/master | B8 / cadence resume |
| https://www.qemu.org/blog/ | post-11.0.0 |
| https://libvirt.org/news.html | post-12.3.0 |
| https://docs.mesa3d.org/relnotes/ | post-26.1.1 / 26.0.8 |
| https://release.gnome.org/calendar/ | **GNOME 50.2 ship (2026-05-23, 3 days)**, 51.alpha (2026-06-27) |
| https://github.com/microsoft/WSL/releases | post-2.7.7 stable / post-2.8.6 pre-release |
| https://github.com/systemd/systemd/releases | post-260.1 |
| https://github.com/renovatebot/renovate/releases | post-43.186.7 |
| https://mirrors.kernel.org/fedora/releases/44/Everything/x86_64/os/Packages/s/ | shim-16.1-6+ F44 promotion (Anubis-free) |
| https://www.kernel.org/ | stable/longterm version (7.0.9 / 6.12.90 / 6.18.32 as of 2026-05-17) |
| https://access.redhat.com/security/cve/cve-2026-31431 | Copy Fail — CISA KEV (RHSB-2026-002 fixes available) |
| https://www.bleepingcomputer.com/news/security/exploit-available-for-new-dirtydecrypt-linux-root-escalation-flaw/ | **CVE-2026-31635 DirtyDecrypt (NEW)** |
| https://blog.cloudlinux.com/ptrace-exit-race-cve-2026-46333-mitigation-and-kernel-update | **CVE-2026-46333 ssh-keysign-pwn (NEW)** |

---

## Follow-up questions raised (resolved + unresolved)

**Resolved this pass:**
- **P5 NVIDIA May 2026 security bulletin (cadence-due)** — RESOLVED: bulletin a_id/5821 published 2026-05-19; project pins already satisfy all Linux fix floors.

**Carried forward (still unresolved — out of research-only scope):**
1. **Does any GitHub workflow (`.github/workflows/`) still call `ublue-os/bootc-image-builder-action`?** Migrate to `osbuild/bootc-image-builder-action` if so.
2. **Where does `automation/42-cosign-policy.sh` get the cosign binary, and is it pinned to a digest?** Confirm ≥ 3.0.6.
3. **Are MiOS SELinux site modules going into `/etc/selinux/targeted/active/modules/400/` (persists) or `/usr/lib/selinux/` (wiped on bootc update)?**
4. **Does the project run K3s in HA mode or single-node sqlite mode?** Affects etcd-migration urgency.
5. **Has `automation/52-bake-kvmfr.sh` been verified to sign at image-build time, not first-boot?** Once ucore-hci LTS bumps to 6.18 (issue #362), must also apply `vmalloc.h` / `MODULE_IMPORT_NS("DMA_BUF")` patches.
6. **Is fapolicyd's trust DB rebuilt at image-build time (`fapolicyd-cli --update`) or relying on the dnf plugin?**
7. **GNOME 50 in `ucore-hci:stable-nvidia` yet?**
8. **Does the project use AMD iGPU at all?** AMDGPU CVE cluster hits the 9950X3D iGPU unless `amdgpu` is blacklisted.
9. **Does `mios-sysext-pack.sh` consume systemd 260's central config (`/etc/systemd/systemd-sysext.conf`)?**
10. **Which NVIDIA driver line does the project target?** 595.71.x production-feature vs 595.44.x developer-beta vs 580.x LTS.
11. **Is Mesa in the running image on the 25.x or 26.x line?** Likely lags upstream (now 26.1.1 / 26.0.7) by Fedora package pin.
12. **Does Fedora 43/44 actually ship fapolicyd 1.4.x?** Or still 1.3.8 package version?
13. **Does ucore PR #392 land before 2026-06-05 (next shim checkpoint)?** Gates the kernel-CVE remediation path.
14. **Does F44's kernel package set actually carry the CVE-2026-31431 + DirtyDecrypt + ssh-keysign-pwn fixes?** Verify exact F44 kernel pin once PR #392 merges.
15. **Should MiOS apply `modprobe.blacklist=algif_aead algif_skcipher algif_hash algif_rng` as a pre-PR-392-merge defense-in-depth for Copy Fail?** Project-owner decision.

**New this pass:**
16. **Which Fedora kernel build first carries the DirtyDecrypt (`CVE-2026-31635`) fix?** Upstream merged 2026-04-25; need the Fedora erratum to know whether the eventual F44 base bump closes it.
17. **As Fedora progressively Anubis-gates its infra (now bodhi + koji + src + dl.fedoraproject.org), is mirrors.kernel.org stable enough to rely on, or should the project's poll-job target a different mirror (e.g. a regional rsync mirror)?** The substitute path keeps shrinking.

---

## Priority-order rationale

P0 (reverify) first — same reasoning as prior passes. **P1 (PR #392 merge)** stays top of the funnel: it's the only path that unblocks a now-3-CVE local-root cluster (Copy Fail + DirtyDecrypt + ssh-keysign-pwn) plus action items #1 and #2. **P2 (Secure Boot)** is the tightest hard-calendar deadline (~37 days; checkpoint 2026-06-05); the working check path moved to mirrors.kernel.org. **P3 (K3s GA + CVE-2026-33186)** is a CVSS-9.1 vuln hiding behind silent release notes — fresh check until GA confirms the grpc-go bump. **P4 (Pacemaker 3.0.2 final)** is the closest "expected within days" event. **P5 (GNOME 50.2 + DirtyDecrypt erratum)** are two near-term confirmations (50.2 due 2026-05-23). The NVIDIA May bulletin watch is **resolved** and drops off the funnel. **P6 (Podman 6.0 RC)** is no longer time-critical. **P7–P10** are slower-moving monthly checks.

Anything not on this list can be skipped tomorrow unless an upstream release explicitly demands inclusion. **Tomorrow's run should overwrite this file with its own next-day agenda.**
