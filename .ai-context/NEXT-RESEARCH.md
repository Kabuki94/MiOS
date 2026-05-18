# NEXT-RESEARCH — agenda for next scheduled-research pass

> Written by `scheduled-research-daily` on 2026-05-18 (UTC). Tomorrow's run should start here.

---

## ACTION REQUIRED items (carry forward until resolved)

These are upstream signals that imply a build-breaking or security change to the project. **The research agent never applies these.** They are surfaced here for human review and follow-up.

1. **ACTION REQUIRED: Base image is on an archived/deleted repo + daily-rebuild cadence stalled.** `Containerfile` line 19 still references `ghcr.io/ublue-os/ucore-hci:stable-nvidia`. `bsherman/ucore-hci` returns HTTP 404. `ublue-os/ucore-hci` GHCR container's latest tag is still `stable-nvidia-lts-20260511` — **now 7 days old as of 2026-05-18**, an unusual stall for the ublue-os daily-bake. Migration target remains `ghcr.io/ublue-os/ucore:stable-nvidia-lts`. Requires updating `renovate.json` `customManagers` regex `depName` and `image-versions.yml` `renovate: datasource=docker depName=` line. **Cannot be done by Renovate automerge.** Compounded by ACTION #9 — no fresh bake means no kernel CVE backports propagated.

2. **ACTION REQUIRED: Pin cosign ≥ 3.0.6** wherever the project verifies signatures. Cosign GHSAs `GHSA-w6c6-c85g-mmv6`, `GHSA-wfqv-66vq-46rm`, `GHSA-whqx-f9j3-ch6m` all fixed in 3.0.6 / 2.6.3. Also `CVE-2026-22703` (Rekor entry not bound to artifact — verification bypass) fixed in 2.6.2 / 3.0.4. Verify the cosign binary baked into the image and the `automation/42-cosign-policy.sh` flow; also confirm CI workflows pass `--bundle` (v3 requires it where v2 made it optional). *(Note: `CVE-2026-31431` is the Linux kernel "Copy Fail" LPE, NOT a cosign CVE — see ACTION #9.)*

3. **ACTION REQUIRED: NVIDIA kmod pin — bump LTS floor + clarify feature branch.** `kmod-nvidia-open` must be ≥ **580.159.04** (LTS, released 2026-05-14). If pinning the feature branch, **distinguish 595.71.05 production-feature (2026-04-28) from 595.44.08 developer-beta (2026-05-15)** — they are separate lines, not a single "595.x" pin. Jan 2026 advisory `a_id/5747` covers CVE-2025-33219 (integer overflow → LPE/RCE), CVE-2025-23277, CVE-2025-23280 (UAF). No May 2026 bulletin. Update Renovate datasource floor accordingly.

4. **ACTION REQUIRED: Secure Boot 2023-CA shim refresh before 2026-06-26 (~39 days).** MS 2011 CA expires for new signatures on that date. **Fedora 44 final still ships `shim-16.1-5` (2021-key signed only)** as of 2026-05-18. Rawhide has `shim-16.1-6` (2023-key); bodhi.fedoraproject.org is now Anubis-gated, so direct status check is blocked. **Hard checkpoint: 2026-06-05** — if shim-16.1-6 is not in F44 stable by then, MiOS needs a fallback. Pull Fedora's 2023-CA-signed shim into the MiOS image before then; apply Microsoft DBX update via `fwupdmgr` on target hardware. Already-running systems keep booting; only new installs onto firmware that has updated `db` would fail without the 2023-signed shim.

5. **ACTION REQUIRED: Migrate from `ublue-os/bootc-image-builder-action` to `osbuild/bootc-image-builder-action`** if CI uses the former (verify in `.github/workflows/` — still not inspected). Upstream maintenance-mode README in ublue-os repo points to the migration.

6. **ACTION REQUIRED: Fix `osautomation` → `osbuild` typo in `image-versions.yml`.** Confirmed `osautomation` GitHub user (ID 2355752) exists with zero public repos / no GHCR packages. The reference should be `ghcr.io/osbuild/image-builder-cli`. Trivial hand-fix.

7. **ACTION REQUIRED (downgraded — deadline pressure relieved): Podman 6.0 GA slipped to Fedora 45.** The Fedora Change Proposal at `fedoraproject.org/wiki/Changes/Podman6` is now tagged `ChangeAcceptedF45` (last edited 2026-03-11). No upstream 6.0 RC has been cut as of 2026-05-18. Pre-flight Quadlet review still required (BoltDB → SQLite, slirp4netns → Pasta, cgroups v1 removal, netavark default iptables → nftables) but is now F45-paced (Oct 2026) rather than late-May 2026.

8. **ACTION REQUIRED: Migrate from `bootc-image-builder` to `image-builder-cli` (now possible, partial parity).** `image-builder-cli` v64 (2026-05-13) shipped PR #510 "drop 'bootc is experimental'" — bootc subcommand is now GA. Canonical container: `ghcr.io/osbuild/image-builder-cli:latest`. **However, public docs only enumerate qcow2 + bootc-installer ISO patterns** — raw, ami, vmdk, vhd, gce are not documented. BIB still has the wider format matrix. Treat as viable alternative for qcow2/ISO workflows only until full parity is documented.

9. **ACTION REQUIRED (informational, no MiOS-owned remediation): Linux kernel CVE cluster expanded — ~12 CVEs now, 2026-05-01 → 2026-05-13.** Hit the MiOS host kernel:
   - **General LPE/network:** `CVE-2026-31431` ("Copy Fail" root LPE), `CVE-2026-43284` ("Dirty Frag" via ESP/RxRPC), `CVE-2026-46300` ("Fragnesia" networking, 2026-05-13).
   - **AMDGPU cluster:** `CVE-2026-43398`, `CVE-2026-43400`, `CVE-2026-43318`, `CVE-2026-43305`, `CVE-2026-43298`, `CVE-2026-43237`, `CVE-2026-43320`. **Lands on the 9950X3D iGPU unless `amdgpu` is blacklisted** — defense-in-depth blacklist worth considering.
   - **DRM core:** `CVE-2026-43300` (panel NULL deref), `CVE-2026-43287` (property-blob memcg).
   - Kernel 6.18.28 / 6.18.30 (mainline) and 6.12.87 / 6.12.88 (LTS) carry the backports.
   - **Tracking:** `ublue-os/ucore` issue #385. Compounded by ACTION #1 — the stalled daily-bake means no fresh tag has shipped the backports.

---

## Priority topics for tomorrow's pass

Ordered by descending value. Rationale captured under each.

### P0 — Re-verify all 9 ACTION REQUIRED items

Touch each upstream link to see if anything shifted in 24h. Secure Boot 2026-06-26 cutover is 38 days; that's the tightest deadline now that Podman 6.0 has slipped. Also re-check the ucore-hci daily-bake cadence — if a new tag lands, the stalled-cadence flag clears.

- `ublue-os/ucore` issue #385 (kernel-bump for Copy Fail): https://github.com/ublue-os/ucore/issues/385
- `ublue-os/ucore` issue #362 (longterm-6.12 → 6.18): https://github.com/ublue-os/ucore/issues/362
- ucore-hci GHCR tags: https://github.com/ublue-os/ucore/pkgs/container/ucore-hci
- Cosign releases: https://github.com/sigstore/cosign/releases
- NVIDIA driver releases: https://github.com/NVIDIA/open-gpu-kernel-modules/releases
- NVIDIA security bulletins: https://nvidia.custhelp.com/app/answers/list/kw/security%20bulletin
- Fedora `shim-16.1-6` Bodhi promotion: https://bodhi.fedoraproject.org/updates/?packages=shim (Anubis-gated; try `koji.fedoraproject.org` and `discussion.fedoraproject.org` as alternates)
- Podman 6.0 release: https://github.com/containers/podman/releases
- `image-builder-cli` releases (post v64): https://github.com/osbuild/image-builder-cli/releases

If any are resolved, **strike them from the ACTION REQUIRED list** in this file and note resolution in `ai-journal.md`.

### P1 — Kernel 6.12.88 / 6.18.30 propagation into `ucore-hci:stable-nvidia-lts`

*Why:* This is now the most important watch item. The CVE cluster is real, the fixes are upstream, but the project's base image is 7 days stale and the kernel-bump tracker (#385) has had no new activity. If the daily-bake resumes, the project gets the AMDGPU + Copy Fail + Fragnesia fixes for free; if it doesn't, project owner needs to consider intermediate mitigations.

*Specific questions:*
- Has a new `stable-nvidia-lts-YYYYMMDD` tag landed?
- If yes, does it carry kernel ≥ 6.12.88?
- Has issue #385 progressed (linked PR, comment, close)?
- Any other ublue-os signal that the bake is intentionally paused?

*Anchor links:* https://github.com/ublue-os/ucore/pkgs/container/ucore-hci, https://github.com/ublue-os/ucore/issues/385.

### P2 — Secure Boot shim-16.1-6 in F44 stable

*Why:* 2026-06-26 cutover is 39 days. Now the tightest deadline. With bodhi.fedoraproject.org Anubis-gated, the primary check method is broken — need alternate sources.

*Specific questions:*
- Has `shim-16.1-6+` reached F44 stable?
- Are there test-day reports of breakage on ucore base?
- Does Fedora's multi-signed shim auto-roll on bootc upgrade or require explicit `fwupdmgr` action?
- **What's the canonical non-bodhi way to check F44 stable package versions?** (`dnf updateinfo`, `koji.fedoraproject.org`, `discussion.fedoraproject.org`?)

*Anchor links:* https://koji.fedoraproject.org/koji/packageinfo?packageID=8650, https://discussion.fedoraproject.org/, https://fedoraproject.org/wiki/Test_Day:2026-01-12_Multi-signed_shim.

### P3 — K3s v1.34.8 / v1.35.5 GA + CVE-2026-33186 callout

*Why:* RCs cut 2026-05-14 have not promoted in the 4-day window through 2026-05-18. CVE-2026-33186 (gRPC-Go authz bypass, CVSS 9.1) is still not explicitly called out in K3s RC notes. K3s GA notes need to confirm grpc-go ≥ 1.79.3 is bundled.

*Specific questions:*
- Has v1.34.8 GA shipped?
- Does the GA release-notes payload mention grpc-go ≥ 1.79.3 / CVE-2026-33186?
- If not, is the bundled grpc-go version inspectable elsewhere (containerd build deps, image manifest)?

*Anchor links:* https://github.com/k3s-io/k3s/releases, https://github.com/advisories/GHSA-p77j-4mvh-x3m3.

### P4 — Podman 6.0 RC tag watch (now F45-paced)

*Why:* GA slip relieves immediate pressure, but an RC tag will still drop at some point. Quadlet schema deltas have not been publicly documented yet — when an RC lands, the project gets concrete diff signal.

*Specific questions:*
- Has any 6.0 RC tag been cut?
- Are Quadlet schema deltas documented anywhere yet (containers.conf split, .container/.pod/.kube key changes)?
- Has the post-Test-Days report been published?

*Anchor links:* https://github.com/containers/podman/releases, https://fedoraproject.org/wiki/Changes/Podman6, https://communityblog.fedoraproject.org/.

### P5 — `image-builder-cli` v65+ + parity progress

*Why:* The bootc subcommand is GA but format matrix is narrower than BIB per the public docs. Tomorrow: check for v65, check for new format support in docs, check for any BIB deprecation timeline.

*Anchor links:* https://github.com/osbuild/image-builder-cli/releases, https://github.com/osbuild/bootc-image-builder/issues, https://osbuild.org/blog/.

### P6 — composefs v1.1 + bootc native-backend GA

*Why:* No tag in 16+ months on composefs side; bootc still flags native composefs backend "experimental." If composefs v1.1 ever cuts and bootc removes the experimental framing, that's a significant on-disk format event for MiOS.

*Anchor links:* https://github.com/composefs/composefs/releases, https://bootc.dev/bootc/experimental-composefs.html.

### P7 — Pacemaker 3.0.2 final

*Why:* 3.0.2-rc2 was cut 2026-05-11. If 3.0.2 final lands, that's the active HA stack release the project should track. Low-priority — Fedora package pin lags by weeks.

*Anchor link:* https://github.com/ClusterLabs/pacemaker/releases.

### P8 — Looking Glass B8 RC + KVMFR kernel ≥6.13 patches upstreaming

*Why:* B7 was 2025-03-06. Cadence is ~2 years but the kernel ≥6.13 compat patches are accumulating in community fork-land. If gnif tags a B8 RC, the project should know within a day.

*Anchor links:* https://github.com/gnif/LookingGlass/releases, https://github.com/gnif/LookingGlass/commits/master/module.

### P9 — Fedora F45 schedule confirmation + GNOME 50.2 ship

*Why:* Wiki schedule page still inaccessible. Need a clean alternate source for F45 alpha/beta dates. Also GNOME 50.2 is due 2026-05-23 (5 days) — if it slips, gives a calendar signal for downstream availability.

*Specific questions:*
- F45 beta date confirmed (consensus 2026-08-25)?
- Atomic Desktops in F45 confirmed using composefs+UKI sealed bootable container path?
- GNOME 50.2 shipped on schedule?

*Anchor links:* https://fedoraproject.org/wiki/Releases/45/Schedule, https://discussion.fedoraproject.org/c/server/coreos/, https://release.gnome.org/calendar/.

### P10 — Gamescope 3.17 tag + HDR fix commit `7d4e835` + RTX 50-series (low priority)

*Why:* Long-horizon signals. Tomorrow: check if any 3.16.24+ point release picks up `7d4e835`, or if Valve cuts 3.17. RTX 50 watch is multi-month — project's 4090 is unaffected.

*Anchor links:* https://github.com/ValveSoftware/gamescope/releases, https://forum.level1techs.com/t/do-your-rtx-5090-or-general-rtx-50-series-has-reset-bug-in-vm-passthrough/228549.

---

## Upstream releases + CVE feeds to monitor

| Source | What to check |
| ------ | ------------- |
| https://github.com/bootc-dev/bootc/releases | post-v1.15.2 |
| https://github.com/osbuild/bootc-image-builder | new container tags |
| https://github.com/osbuild/image-builder-cli/releases | post-v64 |
| https://github.com/ublue-os/ucore | NVIDIA driver pin, issue #385, issue #362 |
| https://github.com/ublue-os/ucore/pkgs/container/ucore-hci | **daily-build cadence — TIGHT WATCH** |
| https://github.com/composefs/composefs/releases | v1.1 cut |
| https://github.com/ostreedev/ostree/releases | post-v2026.1 |
| https://github.com/containers/podman/releases | v6.0 RC tag |
| https://github.com/k3s-io/k3s/releases | **v1.34.8 GA — TIGHT WATCH**, v1.35.5 GA |
| https://github.com/etcd-io/etcd/releases | post-3.5.30 |
| https://ceph.io/en/news/blog/ | Tentacle patch releases, Squid security bulletins |
| https://github.com/ClusterLabs/pacemaker/releases | 3.0.2 final |
| https://github.com/crowdsecurity/crowdsec/releases | post-1.7.8 |
| https://github.com/linux-application-whitelisting/fapolicyd/releases | post-1.4.5 |
| https://github.com/sigstore/cosign/releases | post-3.0.6 |
| https://nvidia.custhelp.com/app/answers/list/kw/security%20bulletin | May/Jun 2026 bulletin (if any) |
| https://github.com/NVIDIA/open-gpu-kernel-modules/releases | post-580.159.04 / post-595.71.05 / post-595.44.08 |
| https://github.com/NVIDIA/nvidia-container-toolkit/releases | post-1.19.0 |
| https://github.com/gnif/LookingGlass/releases | B8 |
| https://www.qemu.org/blog/ | post-11.0.0 |
| https://libvirt.org/news.html | post-12.3.0 |
| https://docs.mesa3d.org/relnotes/ | post-26.1.0 |
| https://release.gnome.org/calendar/ | GNOME 50.2 ship (2026-05-23), 51.alpha (2026-06-27) |
| https://github.com/microsoft/WSL/releases | post-2.7.5 |
| https://github.com/systemd/systemd/releases | post-260.1 |
| https://github.com/renovatebot/renovate/releases | post-43.182.4 |
| https://koji.fedoraproject.org/koji/packageinfo?packageID=8650 | shim-16.1-6+ F44 promotion (alt to bodhi) |
| https://github.com/bootc-dev/bootc/issues/899 | `/etc/bootc/kargs.d` merge RFE |
| https://github.com/bootc-dev/bootc/issues/946 | rollback-after-switch sharp edge |
| https://github.com/NVIDIA/nvidia-container-toolkit/issues/1735 | nvidia-cdi-refresh ordering |
| https://forum.level1techs.com/t/do-your-rtx-5090-or-general-rtx-50-series-has-reset-bug-in-vm-passthrough/228549 | RTX 50 reset bug |
| https://access.redhat.com/security/cve/cve-2026-31431 | Copy Fail tracking |
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
8. **Does the project use AMD iGPU at all?** CVE-2026-43398 + the AMDGPU cluster hit the 9950X3D iGPU unless the `amdgpu` driver is blacklisted. If MiOS doesn't actually use the iGPU, a blacklist is a defense-in-depth move.
9. **Does the project's `mios-sysext-pack.sh` consume systemd 260's new central config (`/etc/systemd/systemd-sysext.conf`)?**

**New this pass:**
10. **Which NVIDIA driver line does the project target?** 595.71.x production-feature vs 595.44.x developer-beta vs 580.x LTS are now three distinct lines. The `image-versions.yml` / Renovate config should specify which one.
11. **Is Mesa in the running `ucore-hci:stable-nvidia` image on the 25.x or 26.x line?** Knowledge doc baseline corrected to 26.1.0 (2026-05-06), but the project image likely lags the upstream Mesa release by Fedora package pin.
12. **Does Fedora 43/44 actually ship fapolicyd 1.4.x?** Or is the OS still on the 1.3.8 package version? Knowledge-doc correction to 1.4.5 is upstream-latest, but the project pins by Fedora package, not upstream.

---

## Priority-order rationale

P0 (reverify) first — same reasoning as prior passes: a 24h-old ACTION REQUIRED that's resolved is wasted work tomorrow. **P1 (kernel propagation)** is the highest-pressure new watch — CVE cluster is real, base image is stale. **P2 (Secure Boot)** is the tightest hard-calendar deadline (39 days) now that Podman 6.0 has slipped. **P3 (K3s GA + CVE-2026-33186)** is a CVSS-9.1 vulnerability hiding behind silent release notes — worth a fresh check each pass until GA confirms grpc-go bump. **P4 (Podman 6.0 RC)** is no longer time-critical but is still the single biggest project-side scheduling event when it lands. **P5 (image-builder-cli)** is strategic, lower-pressure. **P6–P10** are slower-moving monthly checks.

Anything not on this list can be skipped tomorrow unless an upstream release explicitly demands inclusion. **Tomorrow's run should overwrite this file with its own next-day agenda.**
