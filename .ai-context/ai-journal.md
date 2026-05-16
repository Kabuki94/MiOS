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
