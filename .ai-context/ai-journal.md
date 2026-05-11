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
