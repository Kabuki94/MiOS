# NEXT-RESEARCH — agenda for next scheduled-research pass

> Written by `scheduled-research-daily` on 2026-05-19 (UTC). Tomorrow's run should start here.

---

## ACTION REQUIRED items (carry forward until resolved)

These are upstream signals that imply a build-breaking or security change to the project. **The research agent never applies these.** They are surfaced here for human review and follow-up.

1. **ACTION REQUIRED (ESCALATED): CVE-2026-31431 "Copy Fail" CISA KEV deadline already PAST (2026-05-15).** MiOS LTS base image (`stable-nvidia-lts-20260511`) is built before the kernel fix landed and therefore is vulnerable to a root LPE that has federal-tier severity framing. Vulnerable kernels ≤6.18.21 / ≤6.19.11 / ≤6.12.84; fixed in 6.18.22 / 6.19.12 / 7.0. **The remediation path is `ublue-os/ucore` PR #392 (F43→F44 base migration) — currently open, unmerged, unreviewed.** Until PR #392 merges and a new image is cut, MiOS is exposed. Defense-in-depth: project owner may consider unprivileged-user `kernel.unprivileged_userns_clone=0` and `kernel.dmesg_restrict=1` hardening; the LPE primitive is `algif_aead` AF_ALG and can be mitigated by disabling AF_ALG (`modprobe.blacklist=algif_aead algif_skcipher algif_hash algif_rng`).

2. **ACTION REQUIRED: Base image is on an archived/deleted repo + cadence stalled 8 days + upstream main idle 12 days.** `Containerfile` line 19 still references `ghcr.io/ublue-os/ucore-hci:stable-nvidia`. `bsherman/ucore-hci` returns HTTP 404. `ublue-os/ucore-hci` GHCR latest tag is still `stable-nvidia-lts-20260511` (8 days old). `ublue-os/ucore` main has had zero commits since 2026-05-07 (12 days idle). Migration target remains `ghcr.io/ublue-os/ucore:stable-nvidia-lts`. Requires updating `renovate.json` `customManagers` regex `depName` and `image-versions.yml` `renovate: datasource=docker depName=` line. **Cannot be done by Renovate automerge.**

3. **ACTION REQUIRED: Pin cosign ≥ 3.0.6** wherever the project verifies signatures. Cosign GHSAs `GHSA-w6c6-c85g-mmv6` (now CVE-2026-39395, CVSS 4.3), `GHSA-wfqv-66vq-46rm`, `GHSA-whqx-f9j3-ch6m` all fixed in 3.0.6 / 2.6.3. Also `CVE-2026-22703` (Rekor entry not bound to artifact — verification bypass) fixed in 2.6.2 / 3.0.4. Verify the cosign binary baked into the image and the `automation/42-cosign-policy.sh` flow; also confirm CI workflows pass `--bundle` (v3 requires it where v2 made it optional).

4. **ACTION REQUIRED: NVIDIA kmod pin — bump LTS floor + clarify feature branch.** `kmod-nvidia-open` must be ≥ **580.159.04** (LTS, 2026-05-14). If pinning the feature branch, **distinguish 595.71.05 production-feature (2026-04-28) from 595.44.08 developer-beta (2026-05-15)** — they are separate lines. Jan 2026 advisory `a_id/5747` covers CVE-2025-33219 (integer overflow → LPE/RCE), CVE-2025-23277, CVE-2025-23280 (UAF). No May 2026 bulletin (cadence-due in next ~5–7 days).

5. **ACTION REQUIRED: Secure Boot 2023-CA shim refresh before 2026-06-26 (~38 days).** MS 2011 CA expires for new signatures on that date. **Fedora 44 final still ships `shim-16.1-5` (2021-key signed only)** as last verifiable. Rawhide has `shim-16.1-6` (2023-key); bodhi.fedoraproject.org + koji + src.fedoraproject.org + Fedora Discussion are all Anubis-gated and unreachable from WebFetch. **Working alternate path:** `https://dl.fedoraproject.org/pub/fedora/linux/updates/44/Everything/x86_64/Packages/s/` for the F44 stable repo. Hard checkpoint: 2026-06-05 — if shim-16.1-6 still has not landed in F44 stable by then, MiOS needs a fallback. Apply Microsoft DBX update via `fwupdmgr` on target hardware.

6. **ACTION REQUIRED: Migrate from `ublue-os/bootc-image-builder-action` to `osbuild/bootc-image-builder-action`** if CI uses the former (verify in `.github/workflows/` — still not inspected). The osbuild fork is actively maintained (last commit 2026-05-05, dependabot); the ublue-os fork is confirmed maintenance-mode pointing to the migration.

7. **ACTION REQUIRED: Fix `osautomation` → `osbuild` typo in `image-versions.yml`.** Confirmed `osautomation` GitHub user has zero public repos / no GHCR packages. Reference should be `ghcr.io/osbuild/image-builder-cli`. Trivial hand-fix.

8. **ACTION REQUIRED (downgraded — F45-paced, ~5 months out): Podman 6.0 GA slipped to Fedora 45.** No upstream 6.0 RC has been cut. Pre-flight Quadlet review still required (BoltDB → SQLite, slirp4netns → Pasta, cgroups v1 removal, netavark default iptables → nftables) but is F45-paced (Oct 2026) rather than late-May 2026.

9. **ACTION REQUIRED: Migrate from `bootc-image-builder` to `image-builder-cli` (now possible, partial parity).** `image-builder-cli` v64 (2026-05-13) shipped PR #510 "drop 'bootc is experimental'" — bootc subcommand is now GA. Canonical container: `ghcr.io/osbuild/image-builder-cli:latest`. **However, public docs only enumerate qcow2 + bootc-installer ISO patterns** — raw, ami, vmdk, vhd, gce are not documented. BIB still has the wider format matrix. Treat as viable alternative for qcow2/ISO workflows only until full parity is documented. (Issue #506 is the upstream tracker for composefs+UKI sealed-image bootc backend — strategic Atomic Desktops alignment.)

---

## Priority topics for tomorrow's pass

Ordered by descending value. Rationale captured under each.

### P0 — Re-verify all 9 ACTION REQUIRED items

Touch each upstream link to see if anything shifted in 24h. **Tightest deadlines now: (a) PR #392 merge status — gates the only kernel-CVE remediation path; (b) Secure Boot 2026-06-26 cutover at 38 days.** Also re-check ucore main / `ucore-hci` daily-bake cadence — if main resumes activity or a new tag lands, action #2 unblocks meaningfully.

- `ublue-os/ucore` PR #392 (F43→F44): https://github.com/ublue-os/ucore/pull/392 — **TIGHT WATCH, top-priority**
- `ublue-os/ucore` issue #385 (kernel-bump for Copy Fail): https://github.com/ublue-os/ucore/issues/385
- `ublue-os/ucore` main commit feed: https://github.com/ublue-os/ucore/commits/main
- `ublue-os/ucore` issue #362 (longterm-6.12 → 6.18): https://github.com/ublue-os/ucore/issues/362
- ucore-hci GHCR tags: https://github.com/ublue-os/ucore/pkgs/container/ucore-hci
- Cosign releases: https://github.com/sigstore/cosign/releases
- NVIDIA driver releases: https://github.com/NVIDIA/open-gpu-kernel-modules/releases
- NVIDIA security bulletins: https://nvidia.custhelp.com/app/answers/list/kw/security%20bulletin (May bulletin cadence-due)
- Fedora shim-16.1-6 F44 promotion (alternate path): https://dl.fedoraproject.org/pub/fedora/linux/updates/44/Everything/x86_64/Packages/s/
- Podman 6.0 release: https://github.com/containers/podman/releases
- `image-builder-cli` releases (post v64): https://github.com/osbuild/image-builder-cli/releases

If any are resolved, **strike them from the ACTION REQUIRED list** in this file and note resolution in `ai-journal.md`.

### P1 — PR #392 merge status + kernel package version in new ucore-hci tag

*Why:* This is now THE most important watch item. PR #392 is the only visible remediation path for CVE-2026-31431 (CISA KEV deadline missed). If it merges and a new image is cut: (a) confirm the new tag exists in GHCR; (b) confirm what kernel package version F44 base actually pulls in (must be ≥ 6.18.22 / 6.19.12 / 7.0 to be CVE-31431-fixed). If PR remains unmerged: project owner needs to consider intermediate mitigations (algif_* blacklist, alternate base image).

*Specific questions:*
- Has PR #392 merged?
- If merged, has a new `stable-nvidia-lts-YYYYMMDD` tag landed in GHCR?
- Skopeo-inspect the new image: what kernel package version does it bake?
- Has issue #385 been closed by PR #392? (Same author — likely.)
- Any new ucore main commits at all (idle 12 days as of today)?

*Anchor links:* https://github.com/ublue-os/ucore/pull/392, https://github.com/ublue-os/ucore/pkgs/container/ucore-hci, https://github.com/ublue-os/ucore/issues/385.

### P2 — Secure Boot shim-16.1-6 in F44 stable (via dl.fedoraproject.org)

*Why:* 2026-06-26 cutover is now 38 days. Tightest hard-calendar deadline. With bodhi.fedoraproject.org Anubis-gated, the new working path is the dl.fedoraproject.org mirror tree.

*Specific questions:*
- Curl `https://dl.fedoraproject.org/pub/fedora/linux/updates/44/Everything/x86_64/Packages/s/` and grep for `shim-` — is 16.1-6 present?
- Also check `https://dl.fedoraproject.org/pub/fedora/linux/updates/testing/44/Everything/x86_64/Packages/s/` for the updates-testing pre-stable state.
- Does Fedora's multi-signed shim auto-roll on bootc upgrade or require explicit `fwupdmgr` action?

*Anchor links:* https://dl.fedoraproject.org/pub/fedora/linux/updates/44/Everything/x86_64/Packages/s/, https://fedoraproject.org/wiki/Test_Day:2026-01-12_Multi-signed_shim.

### P3 — K3s v1.34.8 / v1.35.5 GA + CVE-2026-33186 callout

*Why:* RCs cut 2026-05-14 still pre-release at 5 days. CVE-2026-33186 (gRPC-Go authz bypass, CVSS 9.1) still not explicitly called out in K3s RC notes. K3s GA notes need to confirm grpc-go ≥ 1.79.3 is bundled.

*Specific questions:*
- Has v1.34.8 GA shipped?
- Does the GA release-notes payload mention grpc-go ≥ 1.79.3 / CVE-2026-33186?
- If not, can grpc-go version be inferred from Go 1.25.9 vendored deps? (k3s-io/k3s `go.mod` on the RC branches)

*Anchor links:* https://github.com/k3s-io/k3s/releases, https://github.com/advisories/GHSA-p77j-4mvh-x3m3.

### P4 — Pacemaker 3.0.2 final ship

*Why:* rc2 was 2026-05-11; rc1→rc2 gap was ~17 days; rc2 is now 8 days old. Expect final ~2026-05-28 ± a few days. Low-pressure but mature watch.

*Anchor link:* https://github.com/ClusterLabs/pacemaker/releases.

### P5 — NVIDIA May 2026 security bulletin (cadence-due)

*Why:* NVIDIA security bulletins typically arrive monthly; January 2026 was the last bulletin and May is cadence-due. If a May bulletin drops, may require a new driver pin floor.

*Anchor links:* https://nvidia.custhelp.com/app/answers/list/kw/security%20bulletin, https://github.com/NVIDIA/open-gpu-kernel-modules/releases.

### P6 — Podman 6.0 RC tag watch (F45-paced)

*Why:* GA slip relieves immediate pressure, but an RC tag will still drop. Quadlet schema deltas have not been publicly documented yet — when an RC lands, the project gets concrete diff signal.

*Anchor links:* https://github.com/containers/podman/releases, https://fedoraproject.org/wiki/Changes/Podman6.

### P7 — `image-builder-cli` v65+ + parity progress

*Why:* The bootc subcommand is GA but format matrix is narrower than BIB per the public docs. Tomorrow: check for v65, check for new format support in docs, check for any BIB deprecation timeline, check on issue #506 (composefs+UKI sealed-image backend).

*Anchor links:* https://github.com/osbuild/image-builder-cli/releases, https://github.com/osbuild/image-builder-cli/issues/506, https://github.com/osbuild/bootc-image-builder/issues, https://osbuild.org/blog/ (was 404 today — retry).

### P8 — composefs v1.1 + bootc native-backend GA

*Why:* No tag in 16+ months on composefs side; bootc still flags native composefs backend "experimental." If composefs v1.1 cuts and bootc removes the experimental framing, that's a significant on-disk format event for MiOS. Atomic Desktops F45 direction also gated on this.

*Anchor links:* https://github.com/composefs/composefs/releases, https://github.com/composefs/composefs/commits/main, https://bootc.dev/bootc/experimental-composefs.html.

### P9 — Looking Glass cadence (B7 stalled, master idle 4 months)

*Why:* Master has zero visible commits since 2026-01-17 (4-month gap). Worth a continuing watch — if cadence resumes, indicates active development; if not, KVMFR kernel-≥6.13 patches need to be carried by the project itself.

*Anchor links:* https://github.com/gnif/LookingGlass/releases, https://github.com/gnif/LookingGlass/commits/master, https://github.com/gnif/LookingGlass/commits/master/module.

### P10 — Gamescope 3.17 tag + HDR fix commit `7d4e835` (low priority)

*Why:* Long-horizon signal. HDR fix in master not in any tag; #2000/#2018/#2037 all open with no maintainer ack. Tomorrow: check if any 3.16.24+ point release picks up `7d4e835`, or if Valve cuts 3.17.

*Anchor links:* https://github.com/ValveSoftware/gamescope/tags, https://github.com/ValveSoftware/gamescope/issues/2037.

---

## Upstream releases + CVE feeds to monitor

| Source | What to check |
| ------ | ------------- |
| https://github.com/ublue-os/ucore/pull/392 | **PR #392 merge status — TIGHTEST WATCH** |
| https://github.com/ublue-os/ucore/commits/main | upstream activity (idle 12 days) |
| https://github.com/bootc-dev/bootc/releases | post-v1.15.2 |
| https://github.com/osbuild/bootc-image-builder | new container tags |
| https://github.com/osbuild/image-builder-cli/releases | post-v64 |
| https://github.com/osbuild/image-builder-cli/issues/506 | composefs+UKI sealed-image work |
| https://github.com/ublue-os/ucore | NVIDIA driver pin, issue #385, issue #362 |
| https://github.com/ublue-os/ucore/pkgs/container/ucore-hci | daily-build cadence — TIGHT WATCH |
| https://github.com/composefs/composefs/releases | v1.1 cut |
| https://github.com/ostreedev/ostree/releases | post-v2026.1 |
| https://github.com/containers/podman/releases | v6.0 RC tag |
| https://github.com/k3s-io/k3s/releases | **v1.34.8 GA — TIGHT WATCH**, v1.35.5 GA, v1.36.1 |
| https://github.com/etcd-io/etcd/releases | post-3.5.30 |
| https://ceph.io/en/news/blog/ | Tentacle patch releases, Squid security bulletins |
| https://github.com/ClusterLabs/pacemaker/releases | **3.0.2 final — TIGHT WATCH** (rc2 8 days old) |
| https://github.com/crowdsecurity/crowdsec/releases | post-1.7.8 |
| https://github.com/linux-application-whitelisting/fapolicyd/releases | post-1.4.5 |
| https://github.com/sigstore/cosign/releases | post-3.0.6 |
| https://nvidia.custhelp.com/app/answers/list/kw/security%20bulletin | **May/Jun 2026 bulletin — cadence-due** |
| https://github.com/NVIDIA/open-gpu-kernel-modules/releases | post-580.159.04 / post-595.71.05 / post-595.44.08 |
| https://github.com/NVIDIA/nvidia-container-toolkit/releases | post-1.19.0 |
| https://github.com/gnif/LookingGlass/releases | B8 |
| https://www.qemu.org/blog/ | post-11.0.0 |
| https://libvirt.org/news.html | post-12.3.0 |
| https://docs.mesa3d.org/relnotes/ | post-26.0.7 / 26.1.1+ |
| https://release.gnome.org/calendar/ | GNOME 50.2 ship (2026-05-23, 4 days), 51.alpha (2026-06-27) |
| https://github.com/microsoft/WSL/releases | post-2.7.6 stable / post-2.8.6 pre-release |
| https://github.com/systemd/systemd/releases | post-260.1 |
| https://github.com/renovatebot/renovate/releases | post-43.185.1 |
| https://dl.fedoraproject.org/pub/fedora/linux/updates/44/Everything/x86_64/Packages/s/ | shim-16.1-6+ F44 promotion (Anubis-free) |
| https://github.com/bootc-dev/bootc/issues/899 | `/etc/bootc/kargs.d` merge RFE |
| https://github.com/bootc-dev/bootc/issues/946 | rollback-after-switch sharp edge |
| https://github.com/NVIDIA/nvidia-container-toolkit/issues/1735 | nvidia-cdi-refresh ordering |
| https://forum.level1techs.com/t/do-your-rtx-5090-or-general-rtx-50-series-has-reset-bug-in-vm-passthrough/228549 | RTX 50 reset bug (503-prone) |
| https://access.redhat.com/security/cve/cve-2026-31431 | **Copy Fail — CISA KEV** |
| https://access.redhat.com/security/cve/cve-2026-43398 | AMDGPU OOM DoS |
| https://access.redhat.com/security/cve/cve-2026-46300 | Fragnesia |

---

## Follow-up questions raised (resolved + unresolved)

**Resolved this pass:** None new.

**Carried forward (still unresolved — out of research-only scope):**
1. **Does any GitHub workflow (`.github/workflows/`) still call `ublue-os/bootc-image-builder-action`?** Migrate to `osbuild/bootc-image-builder-action` if so.
2. **Where does `automation/42-cosign-policy.sh` get the cosign binary, and is it pinned to a digest?** Need to confirm we're past 3.0.6.
3. **Are MiOS SELinux site modules going into `/etc/selinux/targeted/active/modules/400/` (persists) or `/usr/lib/selinux/` (gets wiped on bootc update)?** The latter is wrong on composefs/bootc.
4. **Does the project run K3s in HA mode or single-node sqlite mode?** Affects etcd-migration urgency.
5. **Has `automation/52-bake-kvmfr.sh` been verified to sign at image-build time, not first-boot?** Once ucore-hci LTS image bumps to 6.18 (issue #362), this script must also apply the `vmalloc.h` / `MODULE_IMPORT_NS("DMA_BUF")` patches.
6. **Is fapolicyd's trust DB being rebuilt at image-build time (`fapolicyd-cli --update`) or relying on the dnf plugin?**
7. **GNOME 50 in `ucore-hci:stable-nvidia` yet?** Can't inspect base image from research-only scope.
8. **Does the project use AMD iGPU at all?** CVE-2026-43398 + the AMDGPU cluster hit the 9950X3D iGPU unless the `amdgpu` driver is blacklisted.
9. **Does the project's `mios-sysext-pack.sh` consume systemd 260's new central config (`/etc/systemd/systemd-sysext.conf`)?**
10. **Which NVIDIA driver line does the project target?** 595.71.x production-feature vs 595.44.x developer-beta vs 580.x LTS are three distinct lines.
11. **Is Mesa in the running `ucore-hci:stable-nvidia` image on the 25.x or 26.x line?** Knowledge doc baseline corrected to 26.1.0 / 26.0.7, but the project image likely lags the upstream Mesa release by Fedora package pin.
12. **Does Fedora 43/44 actually ship fapolicyd 1.4.x?** Or is the OS still on the 1.3.8 package version?

**New this pass:**
13. **Does ucore PR #392 land before 2026-06-05 (next shim checkpoint)?** Gates the only kernel-CVE remediation path.
14. **Does F44's kernel package set actually carry the CVE-2026-31431 fix?** F44 ships kernel ≥ 6.18.x; NVD lists fixed in 6.18.22 / 6.19.12 / 7.0 — need to verify the exact F44 kernel pin once PR #392 merges.
15. **Should MiOS apply `modprobe.blacklist=algif_aead algif_skcipher algif_hash algif_rng` as a defense-in-depth pre-PR-392-merge mitigation for CVE-2026-31431?** This is the AF_ALG primitive surface; if the project doesn't use AF_ALG, blacklisting it neutralizes the Copy Fail LPE primitive directly. Project-owner decision — flagged for ACTION REQUIRED if they want it.

---

## Priority-order rationale

P0 (reverify) first — same reasoning as prior passes. **P1 (PR #392 merge)** is the new top of the funnel — it's the only path that unblocks the CVE-2026-31431 federal-deadline-missed exposure and also unblocks action items #1 and #2. **P2 (Secure Boot)** is the tightest hard-calendar deadline (38 days); new working path via dl.fedoraproject.org makes it tractable. **P3 (K3s GA + CVE-2026-33186)** is a CVSS-9.1 vulnerability hiding behind silent release notes — worth a fresh check each pass until GA confirms grpc-go bump. **P4 (Pacemaker 3.0.2 final)** is the closest "expected to land within days" event. **P5 (NVIDIA May bulletin)** is cadence-due. **P6 (Podman 6.0 RC)** is no longer time-critical. **P7–P10** are slower-moving monthly checks.

Anything not on this list can be skipped tomorrow unless an upstream release explicitly demands inclusion. **Tomorrow's run should overwrite this file with its own next-day agenda.**
