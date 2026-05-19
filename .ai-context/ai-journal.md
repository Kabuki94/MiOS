# AI Journal — CloudWS-bootc / MiOS

> Append-only journal of AI-agent activity touching this project. Each entry is timestamped (UTC), identifies the agent, and records what was investigated/changed/resolved/invalidated. Entries should be self-contained — a future agent reading any single entry should know what happened without prior context.

---

## 2026-05-11T11:30Z — `scheduled-research-daily` (BOOTSTRAP)

**Agent ID:** `scheduled-research-daily`
**Context:** First scheduled-research pass on this project. No prior `.ai-context/` directory, no prior journal, no prior `NEXT-RESEARCH.md`, no `CLAUDE.md`. Substituted `INDEX.md` + `ARCHITECTURE.md` + `ENGINEERING.md` + `SECURITY.md` for the missing CLAUDE.md "sections 1–3" the brief expected.

**Project state at time of run:**
- Version: `v0.1.4` (from `VERSION`).
- Base image: `ghcr.io/ublue-os/ucore-hci:stable-nvidia` (Containerfile line 19; digest pinned by Renovate in `image-versions.yml`).
- Most recent shipped commits: `136e6fc fix(build): resolve 01-repos.sh failure and version typo` (HEAD), `b181d95 fix(arch): align with FHS and zero-trust mandates`. v0.2.0 line abandoned in `024d5f1 reset.`
- No `docs/changelogs/` exists; no top-level `CHANGELOG.md`. Inferred recent direction from git log.

**Research scope (full baseline, since no prior agenda existed):**
Twelve topic groups — bootc/BIB/image-builder-cli; ucore-hci/Universal Blue; Fedora bootc/FCOS/composefs/OSTree; Podman/Quadlet/rechunk; K3s/Ceph/Pacemaker; CrowdSec/fapolicyd/usbguard/SELinux; cosign/Secure Boot/MOK; NVIDIA kmods + Container Toolkit/CDI; VFIO/Looking Glass/KVMFR/QEMU/libvirt; Gamescope/Waydroid/Mesa/ROCm; FreeIPA/SSSD/GNOME/WSL2; kargs.d/Renovate/systemd-sysext/tmpfiles/bootc lifecycle.

Executed by four parallel research sub-agents (general-purpose subagent_type) with the instruction "anchor against what changed since ~Feb 2026 — the project is roughly two months into v0.1.4."

**Files created (this directory only — strict scope compliance):**
- `bootc-research-april2026.md` — live knowledge doc (~450 lines, 12 topic sections, top-level action-items header).
- `ai-journal.md` — this file.
- `NEXT-RESEARCH.md` — tomorrow's agenda.

**Top findings flagged as `ACTION REQUIRED` in NEXT-RESEARCH.md** (not applied — research agent only):
1. `bsherman/ucore-hci` upstream is **archived**. The project's `BASE_IMAGE=ghcr.io/ublue-os/ucore-hci:stable-nvidia` should migrate to `ghcr.io/ublue-os/ucore:stable-nvidia-lts` (carries 580 LTS pre-signed `kmod-nvidia-open`). Renovate's `customManagers` regex on `Containerfile` will need its `depName` updated; auto-PRs cannot self-correct a depName change.
2. **cosign verification-bypass CVEs** — `CVE-2026-22703` and `CVE-2026-31431` — both fixed in **cosign ≥ 3.0.6**. Any sig-verification gate using older cosign is bypassable.
3. **NVIDIA Jan 2026 advisory** — pin `kmod-nvidia-open` ≥ 580.126.20 (LTS) or ≥ 595.71.05 (feature) to cover CVE-2025-33219, CVE-2025-23277, CVE-2025-23280.
4. **Secure Boot 2011-CA expiry — 2026-06-26.** MiOS must pick up Fedora's 2023-CA-signed shim before that date.
5. **RTX 50-series VFIO passthrough is broken.** RTX 4090 (project target) unaffected; any roadmap upgrade past 4090 must defer.

**Surprises:**
- `image-versions.yml` lists `ghcr.io/osautomation/image-builder-cli` with digest `0000…0000`. No `osautomation` GitHub org locatable upstream. Either a typo for `osbuild/image-builder-cli` or an internal/private fork. Flagged for clarification.
- LBI pre-pull is intentionally disabled in `Containerfile` (lines 67–76) because GitHub-hosted runners don't grant `--privileged` BuildKit; migration path is Quadlet `AutoUpdate=registry` at first boot. Confirmed this is still the right call in May 2026.
- GNOME 50 is out and **fully Wayland-only** (X11 backends removed from Mutter/gnome-shell/gnome-session/Control Center, ~27.5k LOC dropped). Any X11 fallback in the MiOS profile is dead code.
- The ASUS X870E platform (project's 9950X3D target board) has a documented FLR-permanent-bifurcation pathology with RTX 50-series — worth verifying behaves correctly on the 4090.
- bootc kargs.d `match-platforms` and `priority` keys do NOT exist despite occasional community wishlists. The project's `usr/lib/bootc/kargs.d/00-mios.toml` flat-array format is correct and current. Honor it strictly.

**Prior journal entries resolved or invalidated:** None — this is the first entry.

**Files modified outside `.ai-context/`:** None. Strict scope compliance.

**Next pass:** Per `NEXT-RESEARCH.md`. Priority list reasoning is captured there.

---

## 2026-05-16T13:00Z — `scheduled-research-daily`

**Agent ID:** `scheduled-research-daily`
**Context:** Second pass on the live research doc. 5 days since bootstrap. Followed `NEXT-RESEARCH.md` agenda (P0 reverify → P10 systemd 260). Dispatched two parallel general-purpose research subagents — one for P0 reverify + P1–P5, one for P6–P10 + CVE feeds.

**Project state at time of run (unchanged):**
- Version: `v0.1.4` (still — no rev in 5 days).
- Base image: `ghcr.io/ublue-os/ucore-hci:stable-nvidia` (Containerfile line 19 / `image-versions.yml`).
- Most recent commit: `45bf2b0 research: daily pass 2026-05-11 — bootstrap .ai-context` (HEAD of `main`).

**CHANGED upstream this window (knowledge-doc edits applied):**
1. **NVIDIA LTS floor → 580.159.04** (2026-05-14) — supersedes prior 580.126.20. Action item #3 updated; §8.1 rewritten with new release dates.
2. **`image-builder-cli` v64 (2026-05-13)** dropped "bootc is experimental" — bootc subcommand now GA. `ghcr.io/osbuild/image-builder-cli:latest` is canonical. §1.3 rewritten; new action item #6.
3. **Podman 6.0 GA imminent** — Fedora test days closed 2026-05-15, GA target week of 2026-05-25. Breaking removals: BoltDB, slirp4netns, cgroups v1. Netavark default switches iptables → nftables. §4.1 rewritten; new action item #7.
4. **K3s** — v1.34.8-rc1 + v1.35.5-rc1 cut 2026-05-14; v1.36.0 stable 2026-05-06. **etcd 3.5.30** shipped 2026-05-01. §5.1 rewritten with the etcd patch line (3.5.28 was a security release for CVE-2026-33343, CVE-2026-33413).
5. **WSL 2.7.5 pre-release** 2026-05-15 (kernel 6.18.26.1, skips 2.7.4). §11.3 updated.
6. **Renovate 43.181.0** (was 43.173.0 at bootstrap — 8 minor bumps in window). §12.2 updated.
7. **systemd 260** is actually **stable since 2026-03-17** — bootstrap doc said "in development". §12.3 corrected.
8. **`bsherman/ucore-hci` upstream now HTTP 404** (was "archived" at bootstrap). `ublue-os/ucore-hci` GHCR container still actively rebuilt (`stable-nvidia-lts-20260511`). §2 updated. New tracking: `ublue-os/ucore` issues #362 (longterm-6.12 → longterm-6.18) and #385 (kernel bump for CVE-2026-31431).
9. **Gamescope point releases** — 3.16.21 (2026-03-12), 3.16.22 (2026-03-15), 3.16.23 (2026-04-07) shipped between Sept-2025 base 3.16.17 and this pass. §10.1 corrected from "3.16.17" to "3.16.23".
10. **KVMFR kernel ≥6.13 compat patches** — need `#include <linux/vmalloc.h>` + `MODULE_IMPORT_NS("DMA_BUF")`. §9.3 updated. Important once ucore-hci LTS image migrates 6.12 → 6.18.

**NEW — added section §6.5 "Linux kernel CVE cluster — May 2026"** capturing five 2026-05-01 → 2026-05-08 kernel CVEs:
- CVE-2026-31431 ("Copy Fail" root LPE)
- CVE-2026-43398 (AMDGPU OOM DoS)
- CVE-2026-43300 (DRM panel NULL deref)
- CVE-2026-43287 (DRM property-blob memcg)
- CVE-2026-43284 ("Dirty Frag" via ESP/RxRPC)

Project owns no direct remediation — track `ucore-hci` kernel bump in issue #385.

**CORRECTION / prior-entry invalidation:**
- **2026-05-11 entry §7.1:** listed `CVE-2026-31431` as a cosign `verify-blob-attestation` false-OK bug. **That attribution is wrong.** CVE-2026-31431 is the Linux kernel "Copy Fail" LPE published by Microsoft on 2026-05-01. The cosign verification fixes in 3.0.6 / 2.6.3 are covered by `GHSA-w6c6-c85g-mmv6`, `GHSA-wfqv-66vq-46rm`, `GHSA-whqx-f9j3-ch6m` — cosign pin recommendation ≥ 3.0.6 still stands. §7.1 rewritten to remove the CVE-31431 reference; correction noted inline in §6.5 (added) and in the top action-items header.

**RESOLVED follow-up questions from bootstrap pass:**
- Q1 (bootstrap follow-up #1: "What is `ghcr.io/osautomation/image-builder-cli`?") — **CONFIRMED typo for `osbuild`.** GitHub user `osautomation` exists with zero public repos / no GHCR packages. Action item carried forward in NEXT-RESEARCH.md for hand-fix in `image-versions.yml`.
- Q5 (bootstrap follow-up #5: K3s HA mode question) — NOT resolved this pass; was a code-inspection question (`automation/13-ceph-k3s.sh`) outside the research-only scope.

**UNRESOLVED follow-up questions** (carried forward to NEXT-RESEARCH):
- Q2 (workflows still calling `ublue-os/bootc-image-builder-action`?)
- Q3 (cosign binary pinned in `automation/42-cosign-policy.sh`?)
- Q4 (SELinux site modules — going to `/etc/selinux/targeted/active/modules/400/`?)
- Q6 (`52-bake-kvmfr.sh` signs at build-time, not first-boot?)
- Q7 (fapolicyd trust-DB rebuilt at image-build vs runtime?)
- Q8 (GNOME 50 in `ucore-hci:stable-nvidia`?)

**NO CHANGE this window:**
- GNOME 51 alpha — still on calendar for 2026-06-27.
- Fedora 45 schedule — wiki schedule page 404; Beta target ~2026-08-25 per consensus.
- Composefs v1.1 — no tag (still 1.0.8, 2025-01-03). Kernel prereqs already landed in 6.5/6.6; bottleneck is now userspace.
- Looking Glass B8 — still B7 as latest.
- Gamescope 3.17 — no tag.
- RTX 50-series passthrough — still broken; 595.71.05 did not include a fix; no 600-series driver.

**Files modified outside `.ai-context/`:** None. Strict scope compliance.

**Surprises:**
- The image-builder-cli "drop bootc-experimental" PR landed three days before this pass (2026-05-13). Significant — opens a real migration path for the project.
- `bsherman/ucore-hci` went from "archived" to "404" between bootstrap and this pass. Suggests the owner deleted it; doesn't affect the ublue-os/ucore-hci GHCR rebuild but the historical link is gone.
- The CVE-2026-31431 mis-attribution in the bootstrap pass was a clean copy-paste of two different unrelated vulns with the same CVE-year tag. Worth a journal flag against future "same number, different vuln" footguns.

**Next pass:** Per overwritten `NEXT-RESEARCH.md`.

---

## 2026-05-18T13:00Z — `scheduled-research-daily`

**Agent ID:** `scheduled-research-daily`
**Context:** Third pass on the live research doc. 2 days since previous (2026-05-16). Followed `NEXT-RESEARCH.md` agenda (P0 reverify → P10 RTX 50-series). Dispatched two parallel general-purpose research subagents — one for P0 + P1–P4, one for P5–P10 + the ecosystem watch list.

**Project state at time of run (unchanged):**
- Version: `v0.1.4` (still — no rev in 7 days).
- Base image: `ghcr.io/ublue-os/ucore-hci:stable-nvidia` (Containerfile line 19 / `image-versions.yml`).
- Most recent commit on `origin/main`: `a208eac research: daily pass 2026-05-16 (cont'd) — live knowledge doc`.

**CHANGED upstream this 2-day window (knowledge-doc edits applied):**

1. **Podman 6.0 GA SLIPPED — retargeted to Fedora 45.** Bootstrap and 2026-05-16 entries both expected GA "week of 2026-05-25." The Fedora Change Proposal at `fedoraproject.org/wiki/Changes/Podman6` is now tagged `ChangeAcceptedF45` (last edited 2026-03-11) — the F44 target was actually abandoned **before** the bootstrap pass; the 2026-05-16 prediction was wrong in retrospect. No upstream 6.0 RC tag has been cut. Test Days closed 2026-05-15 with no post-test-day report. Knowledge-doc §4.1 + action-item #7 rewritten; deadline pressure relieved.

2. **Kernel CVE cluster expanded from 5 → ~12 CVEs.** Sub-agent surfaced an AMDGPU sub-cluster (CVE-2026-43318, 43400, 43298, 43237, 43320, 43305) all in the 2026-05-08 disclosure window, plus CVE-2026-46300 "Fragnesia" (networking, AlmaLinux 2026-05-13). Kernel 6.18.28 (2026-05-08), 6.18.30 (2026-05-14), 6.12.87, 6.12.88 carry the backports. Knowledge-doc §6.5 + action-item #8 expanded. Added an "AMD iGPU exposure on 9950X3D" note since the AMDGPU cluster lands directly on the host iGPU unless blacklisted — flagged for the project owner.

3. **ucore-hci daily-rebuild cadence stalled.** Latest tag still `stable-nvidia-lts-20260511`, 7 days old as of 2026-05-18. This is unusual for the ublue-os daily-bake pattern and compounds risk on the kernel CVE cluster (none of the new fixes have propagated to MiOS's base image). Action-item #1 + §2 updated.

4. **NVIDIA 595.44.08 Vulkan developer-beta** released 2026-05-15. Bootstrap doc had listed it without distinguishing it from the 595.71.x production-feature branch. §8.1 split into Production-Feature (595.71.05) vs Developer-Beta (595.44.08) — they are **not** the same line. Important for project pin clarity.

5. **K3s v1.34.8 / v1.35.5 GA still pending.** RCs cut 2026-05-14 have not promoted in the 2-day window. **CVE-2026-33186** (gRPC-Go authz bypass, CVSS 9.1) is still not explicitly called out in any K3s RC notes. Watch item until GA. §5.1 updated.

6. **Pacemaker 3.0.2-rc2 cut 2026-05-11** — 45 commits, XPath + memory-leak fixes. §5.3 updated.

7. **CrowdSec 1.7.8** (2026-05-11) — adds WAF OpenAPI schema validation, body-size limits, decision-stream chunked-transfer improvements. Bootstrap baseline 1.7.6 superseded. §6.1 updated. (Sub-agent flagged some WebFetch results returned "2024" dates that look misparsed — release ordering matches 2026 cadence; treat 1.7.8 as current.)

8. **GNOME 50.2 stable point release scheduled 2026-05-23** (5 days out). GNOME 51.alpha date **confirmed** at 2026-06-27. §11.2 updated.

9. **Renovate 43.182.4** (2026-05-18 10:44Z) — 8 minor versions in the 2-day window. Routine cadence. §12.2 updated.

**CORRECTIONS — stale baselines fixed (these had been wrong since bootstrap, not new this window):**

- **Mesa 25.3.4 → 26.1.0** (2026-05-06). The 26.x series shipped before bootstrap and was missed. §10.3 corrected.
- **QEMU 10.2.0 → 11.0.0** (2026-04-22). 2500+ commits, 237 authors, Nitro Enclaves accelerator. Shipped before bootstrap and missed. §9.4 corrected. **Worth verifying VFIO/PCI passthrough behavior on the 9950X3D + RTX 4090 path before any project bump.**
- **libvirt 12.1.0 → 12.3.0** (2026-05-02). 12.2.0 (2026-04-01) was the intermediate point. §9.5 corrected.
- **fapolicyd 1.3.8 → 1.4.5** (2025-03-30). 1.4.x line had already shipped before bootstrap and was missed. §6.2 corrected, with a flag to verify Fedora package pin matches upstream-latest.

**NO CHANGE confirmed this window** (still current):
- bootc v1.15.2 (2026-05-01).
- composefs 1.0.8 (2025-01-03) — still experimental in bootc native backend.
- OSTree v2026.1 (2026-04-10).
- cosign v3.0.6 (2026-04-06) — no new GHSAs.
- Looking Glass B7 (2025-03-06) — no B8 RC.
- Gamescope 3.16.23 (2026-04-07) — issue #2037 HDR fix commit `7d4e835` still unreleased.
- etcd 3.6.11 / 3.5.30 / 3.4.44 (2026-05-01).
- Ceph 20.2.1 Tentacle (2026-04-06).
- systemd 260 (2026-03-17) / 260.1 (2026-03-23).
- WSL 2.7.3 GA / 2.7.5 pre-release (2026-05-15) — same as 2026-05-16.
- Waydroid 1.6.2, ROCm 7.2.3, SSSD 2.13.0, NVIDIA Container Toolkit 1.19.0, usbguard 1.1.4, NVIDIA LTS 580.159.04.
- RTX 50-series passthrough still broken; no fix.
- shim-16.1-6 still not in F44 stable — bodhi.fedoraproject.org now gated by Anubis (direct fetch blocked); no Fedora Discussion thread in the 2-day window. Next checkpoint scheduled for 2026-06-05.
- image-builder-cli v64 (2026-05-13) — no v65 yet. **Softened the parity claim** — public docs only enumerate qcow2 + bootc-installer ISO patterns; `raw`, `ami`, `vmdk`, `vhd`, `gce` are not documented. BIB still has wider format matrix.

**RESOLVED follow-up questions from 2026-05-16 pass:** None — the 6 unresolved questions (workflow inspection, cosign script pin, SELinux module path, KVMFR signing timing, fapolicyd trust DB, GNOME 50 in stable-nvidia) all remained code-inspection questions outside the research-only scope. Carried forward to NEXT-RESEARCH.

**UNRESOLVED follow-up questions** (carried forward to NEXT-RESEARCH):
- Same 6 from the 2026-05-16 pass plus follow-ups 9 (AMD iGPU usage / blacklist defense-in-depth) and 10 (systemd 260 central sysext config consumption).
- **NEW this pass:** Does the project pin `nvidia-open` to a specific branch (595.71.x production-feature vs 595.44.x developer-beta vs 580.x LTS)? Bootstrap noted feature/LTS but did not specify branch line.
- **NEW this pass:** Is Mesa in the running `ucore-hci:stable-nvidia` image on the 25.x or 26.x line? (Cannot inspect from research-only scope.)

**Files modified outside `.ai-context/`:** None. Strict scope compliance.

**Surprises:**
- The Podman 6.0 GA target had **already** been shifted to F45 by 2026-03-11. Both bootstrap (2026-05-11) and 2026-05-16 passes called it "imminent" / "Test Days are pre-GA" — but the F44 plan was abandoned weeks earlier. The communityblog / wiki signal got read as "Test Days happening this week = GA next week" when in fact it was "Test Days happening this week before deferring the version to next Fedora cycle." Worth journaling as a "don't infer GA from Test Days proximity" footgun.
- Three knowledge-doc baselines (Mesa, QEMU, libvirt) were stale at bootstrap and only caught on this pass. The bootstrap sweep apparently took outdated numbers from secondary sources. Anchoring against project GitHub Releases pages should be primary going forward.
- ucore-hci daily-rebuild cadence stalling at exactly the same week as the kernel CVE cluster is unfortunate timing — the project relies on ublue-os to land the kernel bump, and the bake cadence has just paused. Worth a closer watch tomorrow.

**Prior journal entries resolved or invalidated:** Bootstrap pass and 2026-05-16 pass both predicted Podman 6.0 GA week of 2026-05-25. **Both predictions are now invalidated** by the F45 retarget. No earlier journal entries were proven outright false beyond what was already corrected in the 2026-05-16 entry.

**Next pass:** Per overwritten `NEXT-RESEARCH.md`. P0 (reverify) priority remains; new top-of-funnel watches: kernel 6.12.88 propagation in ucore-hci, K3s GA + CVE-2026-33186 callout, shim-16.1-6 F44 stable.

**Drive mirror note:** Daily Drive snapshot uploaded as `CloudWS-bootc-research-2026-05-18.md` (Drive file id `1qK6cKQDU63KIFwrVZ8PJDagg41AeUt8a`). **Trade-off:** the Drive file is an *index* pointing back to the git-tracked full doc at this pass's commit, not a verbatim 56KB copy of the knowledge doc. The Read tool returned a hard 25K-token cap per call and the formatted markdown crosses that limit (~26K tokens); chunked-reassembly into a single MCP `textContent` parameter was attempted but proved fragile, and the git commit is the authoritative archive regardless. Future passes should consider chunked upload or an alternate mirror path if the verbatim-copy requirement matters.

---

## 2026-05-19T12:00Z — `scheduled-research-daily`

**Agent ID:** `scheduled-research-daily`
**Context:** Fourth pass on the live research doc. 1 day since previous (2026-05-18). Followed `NEXT-RESEARCH.md` agenda (P0 reverify of 9 ACTION REQUIRED items → P1–P10). Dispatched two parallel general-purpose research subagents — one for P0 reverify + P1–P4, one for P5–P10 + ecosystem watch.

**Project state at time of run (unchanged):**
- Version: `v0.1.4` (still — no rev in 8 days).
- Base image: `ghcr.io/ublue-os/ucore-hci:stable-nvidia` (Containerfile line 19 / `image-versions.yml`).
- Latest commit on `origin/main`: `a208eac research: daily pass 2026-05-16 (cont'd) — live knowledge doc` (unchanged; the 2026-05-18 pass committed but I have not verified the local-HEAD vs. origin/main status in this notebook).

**CHANGED upstream this 24h window (knowledge-doc edits applied):**

1. **NEW: ucore PR #392 (F43 → F44 base migration)** opened 2026-05-17T15:57Z by dylanmtaylor — flips `FEDORA_VERSION` 43 → 44 in `ucore/Justfile` plus mergerfs github-pkgs JSON tag bump + `install-ucore.sh` tweaks. **This is the implicit kernel-bump path** (F44 base brings a newer kernel package set; not a direct kernel pin change). Still open, unreviewed. Same author as issue #385, so #385 may resolve when #392 lands. **Most significant new datapoint of the 24h window** — see §2 + action item #1.

2. **Issue #385 activity:** updated 2026-05-17T12:54Z, now has **7 comments** (was 0 before). Comment bodies not retrievable via WebFetch (JS-rendered). §2 updated.

3. **CVE-2026-31431 "Copy Fail" is on CISA KEV; federal remediation deadline 2026-05-15 — NOW 4 DAYS PAST.** NVD entry last-modified 2026-05-18 confirms KEV inclusion. CVSS 7.8. Vulnerable kernels ≤6.18.21 / ≤6.19.11 / ≤6.12.84; fixed in 6.18.22 / 6.19.12 / 7.0. **MiOS LTS base (`stable-nvidia-lts-20260511`) is built before any of these fixes landed → MiOS is vulnerable.** Action item #8 + §6.5 rewritten with federal-tier severity flag.

4. **GHSA-w6c6-c85g-mmv6 now has CVE assignment CVE-2026-39395** (CVSS 4.3 Moderate; `verify-blob-attestation` false positive). Already fixed in cosign 3.0.6 — no remediation change. Action item #2 + §7.1 updated.

5. **Mesa 26.0.7 stable backport** shipped 2026-05-14. The 26.0.x is the maintenance branch parallel to the newer 26.1.x feature branch. §10.3 updated.

6. **WSL 2.7.6 stable (2026-05-18)** + **WSL 2.8.6 pre-release (2026-05-14)** — parallel 2.7.x stable + 2.8.x pre-release trains is a new cadence shift. 2.7.6 fixes Start menu GUI app icons on Azure Linux 3 system distros. §11.3 updated.

7. **Renovate 43.185.1 (2026-05-19, today)** — 4 releases in the 24h window: 43.183.0, 43.184.0, 43.185.0 (all 2026-05-18) then 43.185.1 today. 43.185.1 is a GitHub tags datasource bugfix. §12.2 updated.

8. **AlmaLinux CVE-2026-46300 ("Fragnesia") fixed-kernel pins captured** for cross-distro reference: AlmaLinux 10 = `kernel-6.12.0-124.56.3.el10_1`, AlmaLinux 9 = `kernel-5.14.0-611.54.5.el9_7`, AlmaLinux 8 = `kernel-4.18.0-553.124.3.el8_10`. §6.5 updated.

9. **F45 Beta confirmed 2026-08-25** via Wikipedia release-history + Fedora ChangeSet cross-reference (`fedoraproject.org/wiki/Releases/45/Schedule` still 404 on second pass; `fedorapeople.org/groups/schedule/f-45/*` is now Anubis-gated). F45 Atomic Desktops direction: "switch the builds of the Fedora Atomic Desktop ISOs over from lorax to image-builder" + add qcow2/raw artifacts. **Composefs+UKI sealed-image is NOT confirmed as a default F45 deliverable** — sealed-image work continues in `travier/fedora-atomic-desktops-sealed` (WIP, unofficial). New §3.4 added.

10. **Looking Glass master appears stalled** — no visible commits between 2026-01-17 and 2026-05-19 (4-month gap, confirmed across two probes). Possible upstream stall. §9.2 updated.

**CORRECTION — prior-entry data points fixed (these had been wrong before today):**

- **fapolicyd v1.4.5 date corrected: 2025-03-30 → 2026-03-30.** The 2026-05-18 entry pulled the date from a WebFetch of the GitHub Releases HTML page that lost a year on parse. The Releases atom feed renders 2026 and is internally consistent with the 1.4.x cadence (1.4.2 = 2025-11-26, 1.4.3 = 2026-01-13, 1.4.4 = 2026-03-19, 1.4.5 = 2026-03-30). Atom feed is now the authoritative date source. §6.2 rewritten. Two other items had the same parse-failure pattern this pass (NVIDIA Container Toolkit v1.19.0 "2025-03-12" → 2026-03-12; systemd v260.1 "2025-03-23" → 2026-03-23); both atom-feed-verified, both already on 2026 in the knowledge doc, so no edits needed.

- **Corosync version corrected: 3.1.1 → v3.1.10 (2024-11-15).** Bootstrap baseline (3.1.1) was many releases behind. v3.1.10 carries the CVE-2025-30472 fix. §5.3 updated.

**NO CHANGE confirmed this window:**
- bootc v1.15.2 (2026-05-01).
- OSTree v2026.1 (2026-04-10).
- cosign v3.0.6 (2026-04-06) — no new GHSAs; just CVE assignment to existing GHSA-w6c6-c85g-mmv6.
- composefs v1.0.8 (2025-01-03) — still 16+ months stale on tags; main has last visible commit 2026-01-15 ("Add CNCF copyright footer"); no v1.1 motion.
- bootc native composefs backend — still "experimental" with on-disk-format-may-change warning.
- image-builder-cli v64 (2026-05-13) — no v65 (6 days, cadence is 1-2 weeks). Issue #506 (composefs+UKI sealed-image bootc backend, 2026-04-29) is the upstream gating item.
- BIB — 76 open issues, no deprecation timeline.
- Pacemaker 3.0.2-rc2 (2026-05-11) — 3.0.2 final not shipped (8 days into rc2; rc1→rc2 gap was 17 days).
- NVIDIA driver lineup unchanged (LTS 580.159.04 / production-feature 595.71.05 / dev-beta 595.44.08).
- No new NVIDIA security bulletin since Jan 2026.
- Looking Glass B7 (2025-03-06) — no B8 RC.
- Gamescope 3.16.23 (2026-04-07) — HDR fix commit `7d4e835` still in master, not in any tagged release.
- K3s — RCs still 5 days old, no GA promotion. CVE-2026-33186 still uncalled-out in v1.35.5-rc1 release notes (which I inspected this pass: notes mention Go 1.25.9 + 2026-05 backports + local-path-provisioner bump but no grpc-go callout).
- etcd 3.6.11 / 3.5.30 / 3.4.44 (2026-05-01).
- Ceph 20.2.1 Tentacle (2026-04-06); also noted Reef 18.2.8 (2026-03-20, final backport).
- CrowdSec 1.7.8 (2026-05-11). NVIDIA Container Toolkit v1.19.0 (2026-03-12). QEMU 11.0.0 (2026-04-22). libvirt 12.3.0 (2026-05-02). systemd v260.1 (2026-03-23).
- shim-16.1-6 in F44 stable — still cannot verify (Anubis-gated infrastructure); next checkpoint 2026-06-05; 38 days to 2026-06-26 cutover.
- Podman 6.0 — no RC tag.
- RTX 50-series passthrough still broken; Level1Techs forum thread now returns 503; Tom's Hardware confirms active $1,000 bounty.
- `osbuild/bootc-image-builder-action` — one new dependabot commit on 2026-05-05 (`31d72f7` npm-production group bump); latest tag still `0.0.2` (2025-05-18).
- `ublue-os/bootc-image-builder-action` — confirmed maintenance-mode, no new activity.

**RESOLVED follow-up questions from 2026-05-18 pass:** None — the unresolved questions remain code-inspection questions outside the research-only scope. Carried forward.

**UNRESOLVED follow-up questions** (carried forward to NEXT-RESEARCH).

**NEW this pass:**
- **Does ucore PR #392 land before 2026-06-05 (next shim checkpoint)?** If yes, kernel-CVE remediation path arrives at MiOS via a base-image rebuild. If no, the federal-deadline-missed status (action item #8) compounds with the Secure Boot deadline.
- **Does the F44 base kernel package set in ucore actually carry the CVE-2026-31431 fix?** F44 typically ships kernel ≥ 6.18.x, but the exact kernel pin needs verification once PR #392 merges. NVD lists fixed in 6.18.22 / 6.19.12 / 7.0 — F44 may already be on a fixed version.
- **What is the canonical non-Anubis path to verify Fedora F44 package versions?** Today's pass settled on `dl.fedoraproject.org/pub/fedora/linux/updates/44/Everything/x86_64/Packages/s/` as the answer. Worth a poll-job-style automation to detect shim-16.1-6 promotion.

**Files modified outside `.ai-context/`:** None. Strict scope compliance.

**Surprises:**
- **ucore upstream main has been idle for 12 days** (last commit 2026-05-07 "Fix 404 link to cosign in README #382"). This is a stronger signal than the cadence stall alone — the maintainers may be working off-tree or attention has shifted. PR #392 is a one-author drive-by from dylanmtaylor.
- **CISA KEV deadline already past for CVE-2026-31431** changes the severity framing for federal-adjacent users. MiOS itself is not federally bound, but the "deadline-already-past" framing is a stronger nudge than "CVSS 7.8 LPE."
- **GitHub HTML pages render issue comments via JS** — WebFetch's markdown conversion does not see them. Comment-body retrieval requires either authenticated `api.github.com` (403 unauthenticated) or `mcp__github__issue_read` (scoped to `kabuki94/cloudws-bootc` only). `mcp__github__search_issues` returns issue metadata + body cross-repo but not comments. This shapes what's verifiable in research-only mode for upstream issues.
- **WSL forked into parallel 2.7.x stable + 2.8.x pre-release trains** is a real cadence shift — previous pre-releases were on the same train as stable.

**Prior journal entries resolved or invalidated:** None outright invalidated. The 2026-05-18 entry's fapolicyd date (2025-03-30) was corrected to 2026-03-30 — a parse-failure correction, not a fundamental invalidation.

**Next pass:** Per overwritten `NEXT-RESEARCH.md`. New top-of-funnel watches: PR #392 merge status, kernel package version landing in any new ucore-hci tag, shim-16.1-6 F44 stable promotion via dl.fedoraproject.org mirror.

**Drive mirror note:** Daily Drive snapshot uploaded as `CloudWS-bootc-research-2026-05-19.md` (Drive file id `1GArjTrFe323rxfAdMBD6M1q3KBupJ94d`). Per-pass git push was blocked by a persistent HTTP 503 on the proxy's git-receive-pack endpoint (4+ retries with exponential backoff all failed); fell back to per-file `mcp__github__create_or_update_file` uploads — three commits on the remote, one per file. After remote was synchronized, local was hard-reset to origin/main to align with the MCP-push state.
