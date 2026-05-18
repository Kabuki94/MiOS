# CloudWS-bootc / MiOS — Upstream Research (live document)

> **Status:** Bootstrapped 2026-05-11 by `scheduled-research-daily`. First research pass — no prior agenda existed, so this is the full baseline sweep across the 12 topic groups enumerated in the brief.
> **Project version pinned at:** v0.1.4 (`VERSION` file).
> **Base image:** `ghcr.io/ublue-os/ucore-hci:stable-nvidia` (digest-pinned via Renovate in `image-versions.yml`).
> **Scope:** This doc tracks upstream state and project-relevant deltas. Refine in place; mark revisions inline with `(updated YYYY-MM-DD: <reason>)`. Add new findings as dated subsections under the relevant topic. Remove proven-false entries and note removal in the journal.

---

## Top-priority action items (current — 2026-05-18)

These are flagged in `NEXT-RESEARCH.md` as `ACTION REQUIRED`. They are surfaced here for visibility but **never applied by the research agent itself.**

1. **Base image is on an archived/deleted repo.** `bsherman/ucore-hci` returns HTTP 404 (updated 2026-05-16: was "archived" — now deleted or made private). Dev consolidated under `ublue-os/ucore`; `ghcr.io/ublue-os/ucore-hci:stable-nvidia-lts` container is actively rebuilt by that org. New canonical tag for the NVIDIA-LTS profile MiOS targets remains `ghcr.io/ublue-os/ucore:stable-nvidia-lts` (pre-signed `kmod-nvidia-open` 580 LTS). Renovate cannot self-correct a depName change — must be edited by hand. **Watch `ublue-os/ucore` issue #385** — kernel bump pending to address kernel Copy Fail CVE (see item 8). (updated 2026-05-18: **daily-rebuild cadence appears stalled** — last `stable-nvidia-lts-*` tag still `stable-nvidia-lts-20260511`, now 7 days old. This is unusual for the ublue-os daily-bake pattern; it means the AMDGPU CVE cluster from 2026-05-08 is **not yet** propagated to MiOS's base image. Verify the next refresh ships kernel ≥6.12.88 / 6.18.30.)
2. **cosign verification bypass — patch immediately.** `CVE-2026-22703` (Rekor entry not bound to artifact) fixed in **cosign 2.6.2 / 3.0.4**. Multiple cosign GHSAs (`GHSA-w6c6-c85g-mmv6`, `GHSA-wfqv-66vq-46rm`, `GHSA-whqx-f9j3-ch6m`) all fixed in **cosign ≥ 3.0.6 / 2.6.3**. Any signature-verification gate using older cosign is bypassable. (updated 2026-05-16: removed mis-attribution of `CVE-2026-31431` to cosign — that CVE is the Linux kernel "Copy Fail" LPE, see item 7.)
3. **NVIDIA driver pin — bump LTS floor.** Pin `kmod-nvidia-open` ≥ **580.159.04** (LTS — 2026-05-14) or ≥ **595.71.05** (feature — 2026-04-28). (updated 2026-05-16: LTS floor lifted from 580.126.20 → 580.159.04; new branch release post the Jan 2026 advisory. The Jan 2026 NVIDIA bulletin advisory `a_id/5747` covers CVEs `CVE-2025-33219`, `CVE-2025-23277`, `CVE-2025-23280` — kernel-module LPE/RCE — and is fully patched in 580.126.09+.)
4. **Secure Boot 2011-CA expiry — 2026-06-26 (~6 weeks out, URGENT).** Microsoft stops signing with the 2011 CA in late June 2026. (updated 2026-05-16: **Fedora 44 final still ships `shim-16.1-5` which is 2021-key signed only** — Rawhide has `shim-16.1-6` with 2023-key signing but it has not landed in F44 stable yet. Track `bodhi.fedoraproject.org` for shim-16.1-6+ updates-testing → stable promotion.) MiOS image must pick up Fedora's **2023-CA-signed shim** before that date or new installs onto firmware that has updated `db` will fail. Already-running systems continue to boot.
5. **RTX 50-series VFIO passthrough is broken.** Reset bug acknowledged by NVIDIA, no fix shipped (verified 2026-05-16; 595.71.05 LTS / 595.x feature did NOT ship a fix; no 600-series driver yet; kernel 6.18 ships no Blackwell-specific FLR/IOMMU 1:1 patches). RTX 4090 (project's target) is unaffected, but any roadmap upgrade should be deferred.
6. **`image-builder-cli` v64 (2026-05-13) — `bootc` subcommand now GA** (updated 2026-05-16). PR #510 dropped "bootc is experimental". Canonical container is `ghcr.io/osbuild/image-builder-cli:latest`. **Confirms `ghcr.io/osautomation/...` reference in `image-versions.yml` is a typo for `osbuild`** — the `osautomation` GitHub user exists with zero public repos / no GHCR packages. **MiOS can now plan migration from `bootc-image-builder` to `image-builder-cli` as the unified tool** — but BIB remains a separate active repo, so this is "now possible" not "forced".
7. **Podman 6.0 GA — TARGET SLIPPED to Fedora 45** (updated 2026-05-18: was "imminent — week of 2026-05-25"). The Fedora Change Proposal at `fedoraproject.org/wiki/Changes/Podman6` is now tagged `ChangeAcceptedF45` (last edited 2026-03-11) — original F44 plan was abandoned before this research started. **No 6.0 RC tag has been cut as of 2026-05-18** — upstream latest is still `v5.8.2` (2026-04-14). Test Days closed 2026-05-15 but no post-test-day report has been published. **Net effect:** the project has more breathing room than the May-25 deadline implied; the Quadlet pre-flight review is still needed but is now F45-paced (Oct 2026). Breaking removals (unchanged): **BoltDB** (→ SQLite), **slirp4netns** (→ Pasta), **cgroups v1** entirely. netavark switches **iptables → nftables** default. Quadlet 6.0 adds `.artifact` file type, `AppArmor=` key, `HttpProxy=`, `StopTimeout=`, multi-doc `.kube`, templated vol/net deps. **Pre-flight review still required before bumping Podman version label** — any Quadlet relying on slirp4netns/cgroup-v1/BoltDB on-disk state will break.
8. **Linux kernel CVE cluster — expanded to ~10 (2026-05-01 → 2026-05-18)** (updated 2026-05-18: was 5 CVEs; expanded with AMDGPU cluster + Fragnesia). Affects host kernel on AMD 9950X3D + RTX 4090. **Kernel 6.18.28 (2026-05-08) and 6.18.30 (2026-05-14)** ship the backports; on LTS-6.12, **6.12.88** ships them.
   - `CVE-2026-31431` — "Copy Fail" root LPE (Microsoft advisory 2026-05-01).
   - `CVE-2026-43398` — AMDGPU user-queue wait ioctl OOM DoS (NVD 2026-05-08).
   - `CVE-2026-43400` — AMDGPU `amdgpu_userq_signal_ioctl` OOM DoS, missing bounds check.
   - `CVE-2026-43318` — AMDGPU DMA-BUF sync GPU page faults (fixed 6.15.3 / 6.14.10 / 6.12.20).
   - `CVE-2026-43305` — AMDGPU DC `dmplane_atomic_check` deadlock on error path (backport in 6.13.12 / 6.12.20).
   - `CVE-2026-43298` — AMDGPU VCN 2.5 VF teardown UAF (SR-IOV).
   - `CVE-2026-43237` — AMDGPU stale DMA fences → kernel panic.
   - `CVE-2026-43320` — AMD display DSC eDP (Azure Linux advisory mirror).
   - `CVE-2026-43300` — DRM panel NULL deref (mainline 2026-05-08).
   - `CVE-2026-43287` — DRM property-blob memcg accounting.
   - `CVE-2026-43284` — "Dirty Frag" kernel LPE via ESP/RxRPC (2026-05-08).
   - `CVE-2026-46300` — "Fragnesia" networking (AlmaLinux advisory 2026-05-13).
   - **AMD iGPU exposure on 9950X3D:** the AMDGPU cluster directly hits the 9950X3D iGPU unless `amdgpu` is blacklisted. MiOS uses NVIDIA dGPU for display but iGPU is still bound by default. **Consider `modprobe.d` blacklist as defense-in-depth.**
   - **Mitigation:** Track ublue-os/ucore issue #385 for kernel rev; cherry-pick fixes are upstream-merged on the kernel-6.18 stable branch and on longterm-6.12. **MiOS image rebuild needed after `ucore-hci` kernel bump lands** — see item 1 about the stalled daily-rebuild cadence.

---

## Table of contents

| # | Topic group | Last updated |
| - | ----------- | ------------ |
| 1 | bootc + bootc-image-builder + image-builder-cli | 2026-05-18 |
| 2 | ucore-hci / Universal Blue base | 2026-05-18 |
| 3 | Fedora bootc / FCOS / composefs / OSTree | 2026-05-11 |
| 4 | Podman + Quadlet + rechunk | 2026-05-18 |
| 5 | K3s + Ceph + Pacemaker/Corosync | 2026-05-18 |
| 6 | CrowdSec + fapolicyd + usbguard + SELinux + kernel CVEs | 2026-05-18 |
| 7 | cosign/Sigstore + Secure Boot/MOK | 2026-05-18 |
| 8 | NVIDIA kmods + Container Toolkit / CDI | 2026-05-18 |
| 9 | VFIO/IOMMU + Looking Glass + KVMFR + QEMU + libvirt | 2026-05-18 |
| 10 | Gamescope + Waydroid + Mesa/ROCm | 2026-05-18 |
| 11 | FreeIPA/SSSD + GNOME + WSL2 | 2026-05-18 |
| 12 | kargs.d + Renovate + systemd-sysext + tmpfiles + bootc lifecycle | 2026-05-18 |

---

## 1. bootc + bootc-image-builder + image-builder-cli

### 1.1 bootc (containers/bootc → `bootc-dev/bootc`)
*Recorded 2026-05-11.*

- **Latest:** `v1.15.2` (2026-05-01).
- **Recent line:**
  - `v1.15.2` — `discoverable-partitions` install knob, container `sigpolicy` config knob, ZFS dataset fixes, riscv64 + s390x improvements.
  - `v1.15.1` (Apr 14) — `--karg-delete` CLI flag, Intel VROC install support, IPC namespace fixes.
  - `v1.15.0` (Mar 31) — tag-aware upgrades, `usroverlay --readonly`, composefs verity fixes, pre-flight disk-space checks.
  - `v1.14.x` (Mar 11–12) — experimental `bootc container export --format=tar`, `/usr` overlay status display.
- **Lint rules in current versions:** `nonempty-run-tmp`, `var-tmpfiles` (validates both `/etc/tmpfiles.d` and `/usr/lib/tmpfiles.d`), `kargs.d` syntax validation, single-kernel check in `/usr/lib/modules`. `Containerfile` already runs `bootc container lint` as the final step — these should pass cleanly.
- **`bootc image` subcommands:** `bootc container inspect` (v1.12) and experimental `container export --format=tar` (v1.14.1) added. No native `bootc image list/copy/push` — those remain podman territory.
- **No breaking changes** to TOML formats since v1.11. No CVEs.
- Source: `https://github.com/bootc-dev/bootc/releases`, `https://bootc.dev/bootc/building/kernel-arguments.html`.

### 1.2 bootc-image-builder (BIB)
*Recorded 2026-05-11.*

- **Image:** `quay.io/centos-bootc/bootc-image-builder:latest` (also `:rhel-9`, `:rhel-10`). No formal GitHub releases — versioning lives in container tags.
- **State:** Active. Partition layout customization (`/`, `/boot` min size, extra `/var`-mounted partitions) is mature. Format coverage: `qcow2`, `raw`, `iso` (Anaconda), `ami`, `vmdk`, `vhd`, `gce`. SBOM via osbuild integration.
- **Direction:** Upstream framing: BIB and `image-builder-cli` will **merge** into a unified tool. Treat BIB as the production tool today; not the long-term home.
- Source: `https://github.com/osbuild/bootc-image-builder`, `https://osbuild.org/docs/bootc/`.

### 1.3 image-builder-cli
*Recorded 2026-05-11.* *(updated 2026-05-16: v64 dropped "bootc is experimental" — bootc subcommand now GA; `osautomation` confirmed as typo for `osbuild`.)*

- **Upstream:** `github.com/osbuild/image-builder-cli`. **Latest: v64 (2026-05-13)** — PR #510 "drop 'bootc is experimental'", so the `bootc` subcommand is no longer experimental.
- **Status:** **`image-builder-cli` bootc subcommand is GA but format coverage is not yet at parity with BIB.** Canonical container is `ghcr.io/osbuild/image-builder-cli:latest`. Invocation: `podman run --privileged ghcr.io/osbuild/image-builder-cli build --distro fedora-43 --bootc-ref ... --bootc-build-ref ...`. (updated 2026-05-18: the public usage docs only enumerate **qcow2 + bootc-installer ISO** patterns; **`raw`, `ami`, `vmdk`, `vhd`, `gce` are not documented**. BIB still has the wider format matrix. Soften any claim of "BIB replacement" — until full parity is documented, image-builder-cli is a viable alternative for qcow2/ISO workflows only.)
- **BIB still active.** `osbuild/bootc-image-builder` remains a separate repo with open issues (e.g. #1190 "Bootcfile, a proposal"). No formal unification milestone/RFC has been published; the projects coexist with overlap.
- **`osautomation` typo confirmed.** GitHub user `osautomation` exists with **zero public repos and no GHCR packages**. The `ghcr.io/osautomation/image-builder-cli` reference in `image-versions.yml` is a typo for `ghcr.io/osbuild/image-builder-cli`. Source: https://github.com/osautomation. **Flagged ACTION REQUIRED for hand-fix.**
- Source: https://github.com/osbuild/image-builder-cli/releases, https://osbuild.org/docs/developer-guide/projects/image-builder/usage/.

---

## 2. ucore-hci / Universal Blue
*Recorded 2026-05-11.* *(updated 2026-05-16: `bsherman/ucore-hci` upstream now 404 / deleted-or-private; ublue-os/ucore-hci container rebuilt 2026-05-11; tracking issues #362 and #385 added.)* *(updated 2026-05-18: ublue-os/ucore-hci daily-rebuild cadence appears stalled — latest tag is still `stable-nvidia-lts-20260511` from 7 days ago; issues #385 and #362 still open with no new activity in the window.)*

- **Project base image today:** `ghcr.io/ublue-os/ucore-hci:stable-nvidia` (Containerfile line 19 / `image-versions.yml`).
- **Upstream reality:**
  - `bsherman/ucore-hci` repo **returns HTTP 404** as of 2026-05-16 — was previously archived, now appears deleted or made private. All development consolidated into mainline `ublue-os/ucore`.
  - `ublue-os/ucore-hci` GHCR container had been actively rebuilt by the ublue-os org. Tag `stable-nvidia-lts-20260511` was published 2026-05-11; **no newer tag has appeared in 7 days as of 2026-05-18** — daily-build cadence stalled. Still the migration target, but verify a fresh tag lands before relying on it for the kernel-CVE remediation window.
  - Canonical NVIDIA tags from `ublue-os/ucore`:
    - `:stable-nvidia` — current default NVIDIA driver (590-series open, pre-signed kmod).
    - `:stable-nvidia-lts` — 580 LTS open driver (NVIDIA-recommended "preferred" since March 2026).
    - `:testing-nvidia-lts` — pre-release LTS.
- **Streams:** Daily builds across `stable`/`testing`/`lts`. `stable` tracks FCOS stable stream on kernel **6.12 LTS** for server consistency. `testing` tracks rolling upstream kernel.
- **ZFS:** Now included in all `ucore*` images (NVIDIA and non-NVIDIA) — image count reduction. Verify build assumptions don't conflict.
- **Open tracking issues in `ublue-os/ucore`** (updated 2026-05-18, no new comments since 2026-05-16):
  - **#385** — "Bump kernel to address 'Copy Fail' (CVE-2026-31431)" filed 2026-05-01. **Still open**, no new activity. Kernel rev pending; MiOS rebuilds must wait for this to land in `stable-nvidia-lts`. The 7-day-stale daily-build cadence compounds the risk — the AMDGPU CVE backports (kernel 6.12.88 / 6.18.30, 2026-05-08 → 2026-05-14) are likely also unshipped.
  - **#362** — "Migrate LTS image from longterm-6.12 to longterm-6.18" still open, no new activity. Once merged, MiOS's `iommu=pt` / VFIO assumptions need re-validation on 6.18.
- **Recommendation for MiOS:** Migrate `BASE_IMAGE` from `ghcr.io/ublue-os/ucore-hci:stable-nvidia` to `ghcr.io/ublue-os/ucore:stable-nvidia-lts`. Renovate's `customManagers` regex on `Containerfile` will need its `depName` updated too. **Flagged ACTION REQUIRED.**
- **Note on releases:** `ublue-os/ucore` has **zero published GitHub Releases**; tags are flowed only through OCI registry. Renovate must track via the docker datasource on the GHCR image, not via github-releases.
- Source: https://github.com/ublue-os/ucore, https://github.com/ublue-os/ucore/issues, https://github.com/ublue-os/ucore/pkgs/container/ucore-hci.

---

## 3. Fedora bootc / FCOS / composefs / OSTree

### 3.1 Fedora releases
*Recorded 2026-05-11.*

- **Fedora 44** released **2026-04-28**. F45 branched from rawhide **2026-02-06**.
- **Fedora Atomic Desktops in F44** ship sealed container images using **UKIs + systemd-boot** — Silverblue, Kinoite, Sway Atomic, Budgie Atomic, COSMIC Atomic.
- **DEPRECATION (flagged):** **FCOS 43 disabled OSTree-repo updates** — OCI registry is now the sole update channel. F42 was the transitional dual-channel release. Anything still pulling from `ostree://` for FCOS is broken. Project uses bootc/OCI flow, so this is informational, not a blocker.

### 3.2 composefs
*Recorded 2026-05-11.*

- **Latest:** `v1.0.8` (2025-01-03). **No tagged release in 2026 yet.**
- **Changes since 1.0.7:** fs-verity measurement APIs, EROFS file-backed mount support, userspace signatures replace built-in fs-verity signatures, EROFS bloom filters for xattr lookup, small files inlined.
- **bootc integration:** bootc uses composefs by default for `/` (via ostree). Default base-image config does **not** require signatures/fsverity. The native composefs backend remains **experimental** (bootc docs note on-disk formats may change); waiting on overlayfs kernel changes for GA.
- **Atomic Desktops:** Composefs enabled by default since F42 sealed images; carried into F44.
- Source: `https://github.com/composefs/composefs/releases`, `https://bootc.dev/bootc/experimental-composefs.html`.

### 3.3 OSTree (libostree)
*Recorded 2026-05-11.*

- **Latest:** `v2026.1` (2026-04-10).
- **Changes:** soft-reboot mount fixes (`var`/`sysroot`/`boot`), extension BLS key preservation, `ostree admin status --json` includes origin refspec. Composefs signature support for bootc commits (v2025.7).
- **Deprecation posture:** libostree is the storage substrate beneath bootc; actively maintained, no sunset. FCOS's drop of OSTree-repo *update delivery* is distinct from libostree itself.
- Source: `https://github.com/ostreedev/ostree/releases`.

---

## 4. Podman + Quadlet + rechunk

### 4.1 Podman + Quadlet
*Recorded 2026-05-11.* *(updated 2026-05-16: Podman 6.0 GA imminent — Fedora Test Days closed 2026-05-15, GA target week of 2026-05-25.)* *(updated 2026-05-18: **GA target slipped — Fedora Change Proposal now tagged `ChangeAcceptedF45`** (last edited 2026-03-11, so the F44 target was actually abandoned before the bootstrap pass). No 6.0 RC tag has been cut as of 2026-05-18 — upstream latest is still v5.8.2. Test Days closed 2026-05-15 with no public post-test-day report. New realistic target: F45 (Oct 2026).)*

- **Latest stable:** **Podman v5.8.2** (2026-04-14). **v6.0 GA slipped — Fedora Change retargeted to F45.** No upstream RC tag exists yet. Fedora ran Podman 6.0 Test Days 2026-05-11 → 2026-05-15.
- **Recent line:**
  - `v5.8.2` (Apr 14) — fixes for `unless-stopped` restart policy and Quadlet config bugs; CVE fix (see below).
  - `v5.8.0` (Feb 12) — Quadlet supports multiple units per file via `---` delimiters; new `AppArmor=` and `HttpProxy=` keys for `.container`; `podman update --ulimit`; mandatory BoltDB→SQLite migration.
  - `v5.7.0` (Nov 2025) — TLS/mTLS for remote, multi-YAML `podman kube play`, new **`.artifact` Quadlet unit type**.
- **Podman 6.0 breaking removals** (updated 2026-05-18; target now F45 per `fedoraproject.org/wiki/Changes/Podman6` `ChangeAcceptedF45` tag):
  - **BoltDB removed** — SQLite is the only storage backend. v5.8.0 auto-migration is a hard prerequisite; un-migrated state will not boot under 6.0.
  - **slirp4netns removed** — Pasta is the only rootless networking backend.
  - **cgroups v1 removed** — host must be running unified-cgroup-v2 (Fedora bootc already is, so MiOS unaffected).
  - **netavark default switches iptables → nftables** — any host-side firewall integration assuming iptables backend needs review.
- **Quadlet unit coverage in 6.0:** `.container`, `.volume`, `.network`, `.build` (with `BuildArg`, `IgnoreFile`), `.pod` (with `StopTimeout`), `.kube` (multi-doc YAML), `.image`, `.artifact`. Templated vol/net dependencies stabilized.
- **AutoUpdate=registry:** Behavior unchanged — requires systemd-managed unit, daily timer (`podman-auto-update.timer`). Use `local` policy when CI pre-pulls.
- **LBI (Logically Bound Images):** Stable. **Quadlet remains the recommended path** for bootc-integrated lifecycle — `podman kube` works but is not the bootc-preferred direction. No move away from Quadlet observed.
- **CVE:** **CVE-2026-33414** — Podman 5.8.x Windows Hyper-V backend. **Not relevant to Linux bootc deployments**, but note when bumping `podman` version label.
- **Project status (LBI):** `Containerfile` lines 67–76 currently have LBI pre-pull **disabled** due to lack of `--privileged` BuildKit on GitHub-hosted runners. Quadlet `AutoUpdate=registry` first-boot pull (commented hint in Containerfile) is the migration path.
- **Pre-flight review needed before pulling Podman 6.0** — see `NEXT-RESEARCH.md` ACTION REQUIRED item. Verify no MiOS Quadlet relies on slirp4netns, no iptables-only host integration, no BoltDB on-disk state surviving across the 5.8 → 6.0 boundary. (updated 2026-05-18: deadline pressure relieved by GA slip — pre-flight is still required but is now F45-paced rather than late-May.)
- Source: https://github.com/containers/podman/releases, https://bootc.dev/bootc/logically-bound-images.html, https://communityblog.fedoraproject.org/join-us-for-podman-6-0-test-days-may-11-15-2026/.

### 4.2 `bootc-base-imagectl rechunk`
*Recorded 2026-05-11.*

- Subcommand of `bootc-base-imagectl`; distinct from the `hhd-dev/rechunk` GitHub Action (different impl, similar goal).
- **`--max-layers` guidance:** Upstream examples 64–96. **Project default of 67 is in the sweet spot.** No upstream recommendation has shifted.
- **Bazzite-reported metrics:** ~40% weekly download reduction, 60–80% daily, >90% back-to-back. 6–10 min processing overhead.
- Source: `https://github.com/hhd-dev/rechunk`.

---

## 5. K3s + Ceph + Pacemaker/Corosync

### 5.1 K3s
*Recorded 2026-05-11.* *(updated 2026-05-16: v1.34.8-rc1, v1.35.5-rc1 cut 2026-05-14; v1.36.0 stable 2026-05-06; etcd 3.5.30 shipped 2026-05-01.)* *(updated 2026-05-18: v1.34.8 / v1.35.5 GA still pending — RCs cut 2026-05-14 have not promoted in the 2-day window. **CVE-2026-33186 (gRPC-Go authz bypass via malformed `:path`, CVSS 9.1) is still NOT explicitly called out** in any v1.34.8-rc / v1.35.5-rc release notes. Watch item until GA.)*

- **Latest stable:** `v1.34.7+k3s1`. **NEW: `v1.36.0+k3s1` stable shipped 2026-05-06** (Kubernetes 1.36). **NEW: `v1.34.8-rc1+k3s1` and `v1.35.5-rc1+k3s1` both cut 2026-05-14** — still pre-release as of 2026-05-18. `v1.33.9+k3s1` and `v1.32.11+k3s1` on active maintenance lines.
- **Bundled runtimes:** v1.34 → containerd `2.2.3-k3s1`, runc `1.4.2`; v1.33 → containerd `2.1.x` / runc `1.3.4`.
- **etcd line state** (updated 2026-05-16):
  - v1.34 ships embedded **etcd 3.6.7-k3s1**; v1.33 stays on 3.5.x.
  - **etcd 3.5.30 shipped 2026-05-01** (latest 3.5.x). 3.5.29 (2026-04-01), 3.5.28 (2026-03-20 — security release: CVE-2026-33343 nested-txn authz bypass + CVE-2026-33413 gRPC authn bypass).
  - **Migration: etcd 3.5 → 3.6 is NOT direct** — must transit through one of v3.5.26+ first (3.5.30 is fine).
- **Containerd config:** Now uses **versioned drop-in dirs** (`config.toml.d` for v2, `config-v3.toml.d` for v3) — auto-loaded.
- **SELinux:** `k3s-selinux` policy still ships separately; `selinux=true` in config. No regressions reported.
- **Sqlite remains default** for single-node; embedded etcd still required for HA.
- **CVEs (ecosystem):**
  - `CVE-2026-33186` — gRPC-Go authz bypass via malformed `:path`; fixed in grpc-go v1.79.3. CVSS 9.1 per `GHSA-p77j-4mvh-x3m3`. (updated 2026-05-18: K3s v1.34.8-rc / v1.35.5-rc notes **still do not explicitly call out a grpc-go bump** as of 2026-05-18 — RCs unchanged in the 2-day window. Continues to be a watch item.)
  - `CVE-2026-33343` — etcd nested-txn authz bypass (fixed in 3.5.28).
  - `CVE-2026-33413` — etcd gRPC authn bypass (fixed in 3.5.28).
- Source: https://github.com/k3s-io/k3s/releases, https://github.com/etcd-io/etcd/releases, https://etcd.io/blog/2026/mar20-patch-release/.

### 5.2 Ceph
*Recorded 2026-05-11.*

- **Latest:** **20.2.1 Tentacle** (released 2026-04-06). 19.2.x Squid supported through ~Sept 2026. Reef (18.2) is **EOL**.
- **rook-ceph:** v1.19.x (v1.19.3 patch). Minimum Ceph **19.2.0**.
- **Single-node knobs:** `osd_pool_default_size = 1` and `allowMultiplePerNode: true` for mon+mgr colocation.
- **cephadm:** Container deploy path supported.
- No new 2026 Ceph CVEs surfaced.
- Source: `https://ceph.io/en/news/blog/2026/v20-2-1-tentacle-released/`.

### 5.3 Pacemaker / Corosync
*Recorded 2026-05-11.*

- **Pacemaker:** 3.0.x line (3.0.0 Jan 2025; minors throughout 2025–early 2026). Added **X.509/TLS** for Pacemaker Remote + remote CIB admin. (updated 2026-05-18: **3.0.2-rc2 cut 2026-05-11** — 45 commits, XPath + memory-leak fixes. 3.0.1 final was 2025-08-07; expect 3.0.2 final shortly after the RC stabilizes.)
- **Corosync:** 3.1.1. New extended node/link info API; cfgtool uses it; cfg tracking callback fixed. (updated 2026-05-18: no change.)
- **Breaking from 2.x line (still relevant for any rebase):** Dropped rolling upgrades from <2.0.0; 3.0 nodes cannot talk to Pacemaker 1.1.14 or earlier Remote endpoints. Stricter XML validation; deprecated env vars removed.
- **bootc fit:** Config in `/etc/corosync/` + state in `/var/lib/pacemaker/` — both writable. No Quadlet rework needed.
- No new CVEs.

---

## 6. CrowdSec + fapolicyd + usbguard + SELinux

### 6.1 CrowdSec
*Recorded 2026-05-11.* *(updated 2026-05-18: latest 1.7.8, 2026-05-11; bootstrap baseline 1.7.6 superseded.)*

- **Agent:** **`v1.7.8` (2026-05-11)** — latest. Line cadence in window: 1.7.6 → 1.7.7 (2026-03-30) → 1.7.8 (2026-05-11). 1.7.8 adds **WAF OpenAPI schema validation**, body-size limits, decision-stream chunked-transfer improvements. (Sub-agent noted some WebFetch results returned 2024 dates that look misparsed — release ordering and content match the 2026 cadence; treat 1.7.8 as current.)
- **`cs-firewall-bouncer`:** Continues to support iptables / nftables / **firewalld** backends.
- **SELinux:** **No upstream-shipped CrowdSec SELinux module exists.** MiOS continues to need a local policy module (or confined container) for fapolicyd/enforcing hosts.
- No new CVEs in window.
- Source: https://github.com/crowdsecurity/crowdsec/releases.

### 6.2 fapolicyd
*Recorded 2026-05-11.* *(updated 2026-05-18: bootstrap baseline 1.3.8 was stale — current latest is **v1.4.5 (2025-03-30)**. The 1.4.x line had already shipped before the bootstrap pass and was missed.)*

- **Latest:** **`v1.4.5` (2025-03-30)** — supersedes 1.3.x line. No release in the 2-day window.
- **Historical line context (1.3.x, retained for reference):**
  - 1.3.8 — `ignore_mounts` perf option (drop noisy mounts from fanotify; useful on bootc overlays).
  - 1.3.7 — unified queue enqueue/dequeue, improved `text/x-shellscript` detection, `--ftype` regression fix, state report includes watched mount points.
  - 1.3.6 — larger default subject cache, descriptor leak fix.
- **1.4.x highlights** (verify against image-builder pin): re-check whether Fedora 43/44 has actually shipped 1.4.x; the project may still be on the 1.3.8 Fedora package version. **Worth confirming via `dnf list fapolicyd` inside the Containerfile build context** rather than assuming upstream-latest.
- **bootc trust-DB integration:** `fapolicyd-dnf-plugin` only fires on package transactions; bootc does these at image build, not runtime. **Trust DB needs to be rebuilt at image build time (`fapolicyd-cli --update`) and shipped baked, or regenerated on first boot.** No dedicated dnf5-OSTree-bootc native integration yet.
- No CVEs in window.
- Source: https://github.com/linux-application-whitelisting/fapolicyd/releases.

### 6.3 usbguard
*Recorded 2026-05-11.*

- **Latest:** `1.1.4`. Mature, low-churn project.
- Changes: `FDStreamBuf` destructor fix for fd leak in `FDInputStream`, CI dep bumps.
- Defaults: `ImplicitPolicyTarget=block`, `PresentDevicePolicy=apply-policy`, `InsertedDevicePolicy=apply-policy` remain sensible.
- No CVEs.

### 6.4 SELinux on bootc
*Recorded 2026-05-11.*

- **Policy version:** Fedora 43 `selinux-policy-minimum-42.12-1.fc43` line.
- **Critical persistence rule on composefs/bootc:**
  - `/usr/lib/selinux/.../policy/*` ships in the image; **replaced wholesale** on each bootc update — local edits there do **not** persist.
  - `/etc` and `/var` are mutable. `semodule -i` writes to `/etc/selinux/targeted/active/modules/400/` which **does persist** across bootc updates.
  - For image-time policy: build with `checkmodule` + `semodule_package` + `semodule -i` during the Containerfile build.
- **Project status:** `Containerfile` line 80 installs `selinux-policy-targeted`. SECURITY.md lists site modules (`mios_portabled`, `mios_kvmfr`, `mios_cdi`, `mios_quadlet`, `mios_sysext`). Verify those land in `/etc/selinux/targeted/active/modules/400/` (or are baked correctly into `/usr/share/selinux/packages/`).
- **Operational pain points:** Fedora 43 Silverblue reports of Quadlet units entering restart loops under enforcing; boot-time denial reports surfaced April 2026. Track before promoting any new Quadlet-managed K3s/Ceph/CrowdSec service.
- No CVEs.

### 6.5 Linux kernel CVE cluster — May 2026
*Added 2026-05-16.* *(updated 2026-05-18: expanded from 5 → ~12 CVEs; cluster now dominated by AMDGPU subsystem.)*

Kernel CVEs disclosed in the 2026-05-01 → 2026-05-18 window directly affect the MiOS host kernel (AMD 9950X3D + RTX 4090). Fixes are merged on the kernel-6.18 stable branch and backported to longterm-6.12. **Specifically: kernel 6.18.28 (2026-05-08), 6.18.30 (2026-05-14), 6.12.87, and 6.12.88** carry the backports. MiOS rebuild required after `ublue-os/ucore` issue #385 lands a kernel rev; as of 2026-05-18 issue #385 is still open and the ucore-hci daily-rebuild cadence is stalled.

**General LPE / network:**
- **CVE-2026-31431 — "Copy Fail" (Microsoft advisory 2026-05-01).** Root local privilege escalation. Broad kernel impact. Source: https://access.redhat.com/security/cve/cve-2026-31431, https://www.sysdig.com/blog/cve-2026-31431-copy-fail-linux-kernel-flaw-lets-local-users-gain-root-in-seconds.
- **CVE-2026-43284 — "Dirty Frag" (2026-05-08).** Kernel LPE via ESP / RxRPC fragmentation. Source: https://www.wiz.io/blog/dirty-frag-linux-kernel-local-privilege-escalation-via-esp-and-rxrpc.
- **CVE-2026-46300 — "Fragnesia" (AlmaLinux advisory 2026-05-13).** Networking-stack vulnerability patched 2026-05-13. Source: https://almalinux.org/blog/2026-05-13-fragnesia-cve-2026-46300/.

**AMDGPU cluster** (added 2026-05-18 — most relevant to 9950X3D iGPU):
- **CVE-2026-43398 — AMDGPU user-queue wait ioctl OOM DoS (NVD 2026-05-08).**
- **CVE-2026-43400 — AMDGPU `amdgpu_userq_signal_ioctl` OOM DoS** (missing bounds check).
- **CVE-2026-43318 — AMDGPU DMA-BUF sync GPU page faults.** Fixed in 6.15.3 / 6.14.10 / 6.12.20.
- **CVE-2026-43305 — AMDGPU DC `dmplane_atomic_check` deadlock** on error path. Backported to 6.13.12 / 6.12.20.
- **CVE-2026-43298 — AMDGPU VCN 2.5 VF teardown UAF (SR-IOV).** Not directly relevant to single-host MiOS posture but lives in the same backport set.
- **CVE-2026-43237 — AMDGPU stale DMA fences → kernel panic.**
- **CVE-2026-43320 — AMD display DSC eDP** (Azure Linux advisory mirror; same kernel set).

**DRM core (NVIDIA-friendly path also affected):**
- **CVE-2026-43300 — DRM panel NULL deref (mainline 2026-05-08).** DRM core. Source: https://windowsnews.ai/article/cve-2026-43300-linux-drm-null-pointer-flaw-flagged-by-microsoft-for-windows-environments.417437.
- **CVE-2026-43287 — DRM property-blob memcg accounting (2026-05-08).**

**AMD iGPU exposure on 9950X3D (added 2026-05-18):** MiOS uses NVIDIA dGPU for display, but the AMD iGPU on the 9950X3D is still bound by the kernel `amdgpu` driver unless explicitly blacklisted. The AMDGPU CVE cluster therefore lands on MiOS hosts directly. **Defense-in-depth recommendation:** consider `modprobe.d` blacklist of `amdgpu` if the iGPU is unused in the MiOS workflow. Flagged as a follow-up question for the project owner — research agent does not apply.

**Project status:** None of these have remediation paths the MiOS image owns directly — the fix lands when `ucore-hci`'s base kernel is bumped. Track `ublue-os/ucore` issue #385 (Copy Fail tracker, opened 2026-05-01); also implicitly tracks the AMDGPU cluster since they share the same backport window. Once the kernel rev lands in `stable-nvidia-lts`, MiOS needs a rebuild for the CVE pin to take effect.

**Note on CVE-2026-31431 mis-attribution:** The bootstrap pass on 2026-05-11 listed this CVE under §7.1 (cosign) as a `verify-blob-attestation` bug. **That was wrong** — the CVE is the kernel "Copy Fail" LPE. Corrected here and in §7.1.

---

## 7. cosign / Sigstore + Secure Boot / MOK

### 7.1 cosign / Sigstore
*Recorded 2026-05-11.*

- **Latest:** **cosign 3.0.6** (2026-04-06). policy-controller **v0.15.1** (2026-03-26; bumped internal cosign v2→v3).
- **cosign 3 defaults:**
  - Standardized **Sigstore bundle format** is the default.
  - OCI 1.1 referrer artifacts used for signatures.
  - Single-file trust root + signing service URL.
  - `--bundle` flag for bundle output is **REQUIRED** (was optional in v2).
- **Breaking:** Bundle-format default affects CI signing pipelines and any signature artifacts stored alongside images. policy-controller 0.15.x requires re-checking `ClusterImagePolicy` CRDs against v3 trust-root format.
- **CVEs (FLAG — pin ≥ 3.0.6):** *(updated 2026-05-16: removed mis-attribution of CVE-2026-31431 to cosign — that CVE is the Linux kernel "Copy Fail" LPE, not cosign-related. See §6.5 for the kernel CVE cluster.)*
  - `CVE-2026-22703` — Cosign accepts a Rekor entry that doesn't reference the artifact's digest/sig/key (verification bypass). Fixed in 2.6.2 / 3.0.4.
  - **Cosign GHSAs** (collectively fixed in **3.0.6 / 2.6.3**): `GHSA-w6c6-c85g-mmv6` (published 2026-04-06), `GHSA-wfqv-66vq-46rm`, `GHSA-whqx-f9j3-ch6m`. Pinning cosign ≥ 3.0.6 covers all currently-known sig-verification bypasses.
- **Project status:** `automation/42-cosign-policy.sh` exists. Verify cosign binary version baked in and confirm signature verification flow uses the new bundle format.
- Source: https://blog.sigstore.dev/cosign-3-0-available/, https://github.com/sigstore/cosign/security/advisories.

### 7.2 Secure Boot / MOK
*Recorded 2026-05-11.* *(updated 2026-05-18: bodhi.fedoraproject.org now gated by Anubis — direct fetch blocked. No Fedora Discussion thread in the 2-day window indicates shim-16.1-6 has reached F44 stable. **Schedule next checkpoint for 2026-06-05** — if shim-16.1-6 still has not landed in F44 stable by then, MiOS needs a fallback plan before the 2026-06-26 cutover.)*

- **Microsoft 2011 CA expiry: 2026-06-26.**
  - MS stops signing with the 2011 CA. Firmware DBX-revocation of BootHole/BlackLotus-era binaries signed by it continues.
  - **Already-installed Linux systems keep booting** — the expiry blocks **new** components signed by the 2011 cert, not chains already trusted by firmware.
  - Distros (RHEL 9.7+, Fedora in parallel) are reshipping **shim signed by the 2023 UEFI CA**.
- **Fedora 43 test day** (2026-01-12) validated multi-signed shim coverage.
- **`sbctl`:** Still only signs EFI binaries; akmods/kmod signing flow unchanged.
- **akmod NVIDIA signing on F43:** Standard flow (`openssl`/`kmodgenca` → `mokutil --import` → automatic sign on akmod build) works.
- **Action items (mirror in `NEXT-RESEARCH.md`):**
  - Pull Fedora's 2023-CA-signed shim before mid-June 2026.
  - Apply Microsoft's DBX update via `fwupdmgr` on target hardware; verify firmware accepts updated dbx.
  - Hardware that **only** trusts MS 2011 CA will fail new Fedora shim installs after cutover unless firmware updates.
- **Project status:** `automation/generate-mok-key.sh` and `automation/enroll-mok.sh` exist. Verify they don't pin the 2011 cert chain.

---

## 8. NVIDIA kmods + Container Toolkit / CDI

### 8.1 NVIDIA open kernel modules (`nvidia-open`)
*Recorded 2026-05-11.* *(updated 2026-05-16: LTS floor lifted to 580.159.04, released 2026-05-14.)* *(updated 2026-05-18: **595.44.08 Vulkan developer-beta** confirmed 2026-05-15 — clarified branch split between production-feature 595.71.x and developer-beta 595.44.x. They are not the same branch; pinning to "feature" is ambiguous unless one is specified.)*

- **Production Branch (LTS, "preferred"):** **580.159.04** (released 2026-05-14 — post Jan-2026 advisory). Earlier `580.126.20` / `580.126.09` are still safe-from-CVE but superseded.
- **Feature Branches (DISTINCT):**
  - **Production-Feature: 595.71.05** (2026-04-28). Stable feature line; recommended for non-LTS production.
  - **Developer-Beta: 595.44.08** (2026-05-15). Vulkan Developer Beta. **Not** the same branch as 595.71.x — beta/devel only. Project pins should specify which line they track.
- **No 600-series driver shipped** as of 2026-05-16. Kernel 6.18 ships no Blackwell-specific FLR/IOMMU 1:1 patches.
- **Blackwell (RTX 50-series):** Requires open modules — proprietary blob is unsupported. NVIDIA has fully transitioned to open modules.
- **Open issues to track:**
  - Issue #1117 — RTX 50-series s2idle resume hangs on **kernel 7.0**; works on 6.17.
  - Issue #1132 — GB205 (RTX 5070) BAR1→BAR3 mapping triggers `krcWatchdog` lock with rBAR disabled.
- **CVEs (Jan 2026 bulletin, advisory `a_id/5747` — pin ≥ 580.126.09 or LTS 580.159.04):**
  - `CVE-2025-33219` — integer overflow in kernel module → LPE / RCE.
  - `CVE-2025-23277`, `CVE-2025-23280` — UAF on Linux.
- **No May 2026 NVIDIA bulletin published** (verified 2026-05-16); Jan 2026 remains current.
- **VM-gating impact:** None — `modprobe.d` blacklist + `softdep nvidia pre: vfio-pci` pattern is unchanged. NVIDIA 595 keeps `nvidia-drm.ko modeset=1` default. **Avoid kernel 7.0 on any Blackwell host.**
- **Project status:** Project targets RTX 4090 — passthrough remains stable. RTX 50 upgrade should be deferred (see §9). Project pin floor should track 580.159.04 (LTS) or 595.71.05 (feature).
- Source: https://github.com/NVIDIA/open-gpu-kernel-modules/releases, https://nvidia.custhelp.com/app/answers/detail/a_id/5747.

### 8.2 NVIDIA Container Toolkit + CDI
*Recorded 2026-05-11.*

- **Latest:** `v1.19.0` (current Arch `extra`).
- **Changes:**
  - **v1.18.0** — CDI is now the default runtime mode (legacy mode demoted). Added `nvidia-cdi-refresh.service` systemd unit that auto-regenerates `/var/run/cdi/nvidia.yaml` on install/upgrade/driver-change.
  - **v1.19.0** — improved triggering of `nvidia-cdi-refresh`, **read-only root filesystem support** (initramfs / **bootc** ✓).
- **Open bugs:**
  - #1735 — `nvidia-cdi-refresh.service` ordering constraint can stall boot.
  - #1740 — non-privileged `MIG_STRATEGY=mixed` fails on 1.18+/1.19.0 due to missing cgroup access for `nvidia-cap1/2`.
- **bootc quirk:** `nvidia-ctk cdi generate` must write to `/var/run/cdi/` (tmpfs) not `/etc/cdi/`. v1.19 ro-rootfs support means the systemd unit handles this correctly now.
- **Project status:** `automation/45-nvidia-cdi-refresh.sh` exists — verify it targets the v1.19 layout (not the pre-1.18 manual `ExecStartPre` workaround).

---

## 9. VFIO/IOMMU + Looking Glass + KVMFR + QEMU + libvirt

### 9.1 VFIO / IOMMU / RTX 50-series passthrough
*Recorded 2026-05-11.*

- **State:** **RTX 5090 / RTX PRO 6000 passthrough is broken** as of May 2026 — confirmed reproducible reset bug. Acknowledged by NVIDIA, no fix. RTX 4090 is **unaffected** (project's target — supported).
- **Symptoms (RTX 50 series only):**
  - FLR fails after guest shutdown → `not ready 65535ms after FLR; giving up` → host requires power-cycle.
  - D3cold → D0 transition triggers CPU soft lockup post-shutdown.
  - Blackwell GPUs set PCIe config flag requesting IOMMU 1:1 identity mapping; **kernel 6.17 rejects device config when `iommu=pt` is on cmdline** — use `iommu=on` (DMA mode) for RTX 50.
  - ASUS X870E (the 9950X3D platform!): FLR causes permanent x8 bifurcation until cold boot. **Worth verifying on MiOS target hardware even with RTX 4090.**
- **Mitigations:**
  - `pcie_aspm=off disable_idle_d3=1` on kernel cmdline.
  - Early vfio-pci bind (`softdep nvidia pre: vfio-pci`) — still the correct VM-gating pattern.
  - `nvidia,reset-method=` quirks NOT helpful for Blackwell. `vendor-reset` is AMD-only.
- **Project posture:** Stays on RTX 4090. **Avoid kernel 7.0 with any NVIDIA Blackwell.** Project kargs.d (`00-mios.toml`, `20-vfio.toml`, `13-rtx50-vfio-workaround.toml`) already encode `iommu=pt` + AMD passthrough.

### 9.2 Looking Glass
*Recorded 2026-05-11.*

- **Latest stable:** **B7** (2025-03-06). **No B8 announced.** Cadence is slow (B6→B7 took ~2 years).
- **Recent (post-B7 git-master):** Wayland clipboard crash fix, Wayland protocol error on capture-mode toggle, libdecor builds for GNOME Wayland window decorations.
- **Wayland client:** **Feature parity with X11 in B7** — scaling, fullscreen, clipboard, cursor. Build with `-DENABLE_WAYLAND=ON -DENABLE_X11=OFF` to drop X11 deps on bootc.
- **Project status:** `automation/53-bake-lookingglass-client.sh` exists.

### 9.3 KVMFR (`/dev/kvmfr0`)
*Recorded 2026-05-11.* *(updated 2026-05-16: kernel ≥6.13 build patches noted.)*

- **Source:** Still **DKMS-only**; not in mainline, no submission planned. Lives in LookingGlass repo (`module/`).
- **Secure Boot signing:** Required — Fedora bootc will refuse unsigned `kvmfr.ko`.
  - On immutable rootfs, **signing must happen at image build time** in the Containerfile, not first-boot (DKMS auto-sign assumes mutable rootfs).
  - `/etc/dkms/framework.conf` needs `mok_signing_key=` and `mok_certificate=` for auto-sign on rebuild.
- **Setup:** sysfs-based — `kvmfr.static_size_mb=128` modprobe option; udev rule for `/dev/kvmfr0` owner/group/mode. Older sysconfig approach is deprecated in B7 docs.
- **Kernel compat patches (updated 2026-05-16):** Community patches required to build kvmfr against **kernel ≥6.13** — add `#include <linux/vmalloc.h>` and `MODULE_IMPORT_NS("DMA_BUF")` in `module/module.c`. No upstream submission. Once ucore-hci LTS image migrates from 6.12 → 6.18 (issue #362), these patches must be applied before the rebuild succeeds. Source: https://forums.gentoo.org/viewtopic-t-1176809.html.
- **Project status:** `automation/52-bake-kvmfr.sh` exists.

### 9.4 QEMU
*Recorded 2026-05-11.* *(updated 2026-05-18: bootstrap baseline 10.2.0 was stale — current latest is **11.0.0 (2026-04-22)**; 11.0 had already shipped before the bootstrap pass and was missed.)*

- **Latest stable:** **11.0.0** (2026-04-22) — 2500+ commits, 237 authors, includes new **Nitro Enclaves accelerator**. 10.2.0 (2025-12-24), 10.1.0 (2025-08-26), 10.0.0 (2025-04). No 11.0.x point yet.
- **Recent line (consolidated):**
  - **11.0** — Nitro Enclaves; further VFIO + confidential-guest plumbing; large cross-architecture refactor (verify VFIO/PCI passthrough behavior on the 9950X3D + RTX 4090 path before bumping).
  - 10.2 — **live update via `cpr-exec` migration mode** (in-place upgrade without VM downtime), 9pfs FreeBSD host support, io_uring perf path.
  - 10.1 — **VFIO `guest_memfd` support** for confidential guests (SEV-SNP / TDX passthrough).
  - 10.0 — virtio-scsi multiqueue; new Apple graphics devices.
- **virtiofsd** now external (Rust); libvirt `<idmap>` element for unprivileged virtiofsd.
- **OVMF / swtpm:** No breaking changes.
- Source: https://www.qemu.org/blog/.

### 9.5 libvirt
*Recorded 2026-05-11.* *(updated 2026-05-18: bootstrap baseline 12.1.0 was stale — current latest is **12.3.0 (2026-05-02)**; 12.2.0 (2026-04-01) was also missed.)*

- **Latest:** **`12.3.0` (2026-05-02)** — adds **bhyve I/O throttling** and **Hyper-V guest-info APIs**. `12.2.0` (2026-04-01), `12.1.0` (2026-03-29), `12.0.0` (2026-01-15).
- Recent fixes: AppArmor + snapshot interaction (12.1); dynamic `$PATH` lookup for helpers (12.0); POWER11 CPU support (12.0). Fixed 11.2/11.3 regression (internal snapshot revert broken; post-copy migration crash on destination).
- **virt-manager:** `virt-convert` removed (use `virt-v2v`).
- No VFIO/PCI passthrough XML schema changes through 12.3.0.
- Source: https://libvirt.org/news.html.

---

## 10. Gamescope + Waydroid + Mesa/ROCm

### 10.1 Gamescope
*Recorded 2026-05-11.* *(updated 2026-05-16: 3.16.21/22/23 point releases noted; 3.17 still not tagged.)*

- **Latest:** **3.16.23** (2026-04-07) — point releases 3.16.21 (2026-03-12), 3.16.22 (2026-03-15), 3.16.23 (2026-04-07) all shipped since the bootstrap pass mis-recorded "3.16.17" as latest. **No 3.17 cut yet.**
- **Open regressions (still open as of 2026-05-16):**
  - HDR regression on Fedora 43 / GNOME 49 / KDE Plasma 6.5.3 (issue #2018 — still open).
  - Wayland NVIDIA HDR (issue #2037 — reporter cites upstream commit `7d4e835` as the fix, but no tagged release yet contains it).
  - NVIDIA + Plasma 6.5 Wayland HDR produces grey/washed image (#2000).
- **HDR pipeline on NVIDIA 595 + gamescope 3.16.x has color-correctness regressions** — **hold HDR rollout until next gamescope minor tag.**
- `--expose-wayland` flag still required for native Wayland clients inside Gamescope. HDR requires compositor with `xx-color-management-v4` or `frog-color-management-v1`.
- Source: https://github.com/ValveSoftware/gamescope/tags, https://github.com/ValveSoftware/gamescope/issues/2018, https://github.com/ValveSoftware/gamescope/issues/2037.

### 10.2 Waydroid
*Recorded 2026-05-11.*

- **Latest:** `1.6.2` (Feb 2026). Added **Vulkan support for Intel `xe` driver**.
- **Kernel ABI:**
  - `ashmem` — no longer needed since 1.2.1 (replaced by `memfd` in mainline ≥ 5.18).
  - **`binder` now ships as Rust module (`rust_binder`)** in mainline `linux`/`linux-zen`. Fedora's kernel does **NOT** ship `rust_binder` enabled by default — still need DKMS `binder_linux` for Fedora bootc base. **Must be Secure-Boot-signed.**
- **Android image:** No public confirmation of Android 14/15 bump — Android 13 still default.
- **NVIDIA story:** Still broken-by-default; two workarounds (LXC GPU passthrough via `/dev/nvidia*` nodes + software rendering fallback). Anecdotal reports of unmodified boot on recent driver/Waydroid combos.

### 10.3 Mesa / ROCm
*Recorded 2026-05-11.* *(updated 2026-05-18: Mesa bootstrap baseline 25.3.4 was stale — current latest is **26.1.0 (2026-05-06)**; 25.3.6 (2026-02-19) was the last 25.3.x point.)*

- **Mesa:** **`26.1.0` (2026-05-06)** is the current stable. `25.3.6` (2026-02-19) was final on the 25.3 series. `25.1` in Fedora 43 mainline (verify whether F43/44 packages have moved to the 26.x series yet — `ucore-hci:stable-nvidia-lts` may still ship the 25.x line). RDNA4 ray-tracing optimization, triangle pair compression (GFX12). RX 9000-series stable since 25.1.3 emergency patch.
- **ROCm:** **`7.2.3` (2026-05-04)** — confirmed current latest (no change in window). RX 9070 XT works on Fedora 43 + kernel 6.17+.
- No VFIO host-path deprecations.
- Source: https://docs.mesa3d.org/relnotes.html, https://github.com/ROCm/ROCm/releases.

---

## 11. FreeIPA/SSSD + GNOME + WSL2

### 11.1 FreeIPA + SSSD
*Recorded 2026-05-11.*

- **FreeIPA:** **4.13.0** stable (>170 fixes since 4.12.5). Beta of new responsive WebUI.
- **SSSD:** **2.13.0**. **2.11** introduced generic IdP backend (Keycloak + Entra ID via OAuth 2.0 Device Authorization, RFC 8628).
- **FIDO2 passkey auth** for centrally-managed users continues to stabilize on Fedora — works for sudo and SSH via SSSD PAM stack; physical FIDO2 devices only (no platform passkeys yet).
- No fresh 2026 CVEs.
- **Project status:** `automation/22-freeipa-client.sh` exists.

### 11.2 GNOME
*Recorded 2026-05-11.* *(updated 2026-05-18: GNOME 50.2 stable point release expected **2026-05-23** (5 days from now); GNOME 51.alpha date **confirmed** at 2026-06-27 per `release.gnome.org/calendar`.)*

- **Latest stable: GNOME 50 "Tokyo"** (released **2026-03-18**). **GNOME 50.2 stable point release: 2026-05-23.** GNOME 51 unstable/dev (alpha **2026-06-27** — confirmed, final 2026-09-16). GNOME 49 (Sep 2025) is the old-stable.
- **GNOME 50 is fully Wayland-only.** Mutter, gnome-shell, gnome-session, Control Center had X11 backends **REMOVED** (~27.5k LOC dropped). XWayland remains.
- **NVIDIA explicit-sync** (`linux-drm-syncobj-v1`) mature across Mutter/Mesa/EGL-Wayland.
- VRR enabled on compatible monitors. HDR screen sharing in RDP.
- **GNOME Remote Desktop:** RDP backend with GDM headless login (relevant to MiOS `mios-grd-setup`); HDR screen-share added in 50 RC.
- **Breaking:** X11 session gone. Any X11 fallback in ucore-hci/MiOS profile should be removed.

### 11.3 WSL2 + bootc
*Recorded 2026-05-11.* *(updated 2026-05-16: WSL 2.7.5 pre-release with kernel 6.18.26.1 shipped 2026-05-15; 2.7.4 was skipped.)*

- **Latest pre-release: WSL 2.7.5** (2026-05-15) — **kernel 6.18.26.1**, skips 2.7.4. **2.7.3** (2026-04-25) was the prior pre-release. **2.6 stable** is the first **open-source** release (MIT-licensed). 2.5.6 is the conservative stable channel.
- **2.7.x:** VirtIO networking IPv6, DNS tunneling, statx in VirtioFS, directory mounting; .NET bumped for **CVE-2026-26127** mitigation.
- `wsl --import` + `.wsl` tarball install (since 2.4.4) is the practical path for Fedora bootc images.
- systemd-in-WSL via `/etc/wsl.conf` `[boot] systemd=true` is mature.
- **No first-class bootc-aware path** in microsoft/WSL — you import a bootc-rendered rootfs tarball; `bootc upgrade` works inside, but kernel comes from WSL host. **Kernel 6.18 on WSL 2.7.5 inherits the May 2026 DRM CVE cluster fixes (CVE-2026-43398/43300/43287)** — see §6.5.
- Source: https://github.com/microsoft/WSL/releases.

---

## 12. kargs.d + Renovate + systemd-sysext + tmpfiles + bootc lifecycle

### 12.1 kargs.d
*Recorded 2026-05-11.*

- **bootc v1.15.2 kargs.d format is unchanged from v1.13 baseline.**
- **Canonical keys: `kargs = [...]` (flat array) and optional `match-architectures = [...]`** (Rust target arch names — mind `x86_64` vs `amd64`, `powerpc64` vs `ppc64le`).
- **No `match-platforms` key. No `priority` key. No `[kargs]` table headers. No `append`/`delete` keys.** Searched issues/PRs, official docs, v1.15.x notes — none have landed.
- **Open RFE:** Issue #899 requests `/etc/bootc/kargs.d` merge in addition to `/usr/lib/bootc/kargs.d` — not yet shipped.
- v1.15.2 adds `discoverable-partitions` and a container-signature-policy install knob (unrelated to kargs).
- **Project status:** `usr/lib/bootc/kargs.d/*.toml` files follow the flat-array rule correctly. `00-mios.toml` header reaffirms it. **Honor strictly when editing.**

### 12.2 Renovate
*Recorded 2026-05-11.* *(updated 2026-05-16: now v43.181.0.)* *(updated 2026-05-18: now v43.182.4 — 8 more releases in the 2-day window: 43.181.1 → 43.181.2 → 43.182.0–43.182.4. All feature/bugfix; no security advisories.)*

- **Renovate:** **v43.182.4** (2026-05-18 10:44Z). Routine cadence — no security advisories surfaced. Bootstrap baseline (43.173.0) is now ~9 minor versions behind, but config compatibility unchanged.
- v43 stream: patch-heavy, GitHub noreply email handling for GHE Cloud, GitLab merge-trains MR support, dryRun fixes.
- v41 added JSONC support in configs/presets and Merge Confidence badges by default in `config:recommended`.
- `customManagers` (renamed from `regexManagers`) — automerge enabled by combining `matchManagers`, `matchDatasources`, and `matchUpdateTypes: ["digest", ...]`.
- `docker:pinDigests` + `config:best-practices` still the recommended composition. **Project's `renovate.json` is current — no config drift needed.**
- **`platformAutomerge: false`** still requires two Renovate runs before merge — keep enabled for safe digest pins.
- Caveat: v41 changed branch-name composition for `separateMultipleMinor=true` with customized `branchTopic` — project does not customize `branchTopic`, so not affected.

### 12.3 systemd-sysext
*Recorded 2026-05-11.* *(updated 2026-05-16: systemd 260 stable already shipped 2026-03-17 — bootstrap doc said "in development"; that was wrong.)*

- **systemd 260 stable shipped 2026-03-17** (drops SysV, adds mstack, Varlink metrics). systemd 259.5 latest in 259 series. systemd 258 (Sep 2025) introduced major sysext improvements.
- v258 — sysext respects `ID_LIKE=` from os-release (broader cross-derivative use).
- v259 — `/etc/systemd/systemd-sysext.conf` and `/etc/systemd/systemd-confext.conf` config files; image-policy and mutability configurable centrally. `--mutable=help` lists modes. overlayfs mount options via `$SYSTEMD_SYSEXT_OVERLAYFS_MOUNT_OPTIONS` / `$SYSTEMD_CONFEXT_OVERLAYFS_MOUNT_OPTIONS`. `systemd-stub` loads global sysexts/confexts from `ESP/loader/extensions/*.{sysext,confext}.raw` — relevant if MiOS adopts UKIs.
- **bootc + sysext integration** (sysexts as separate OCI tags managed in lockstep) is still **WIP** — not production-blessed.
- **Project status:** Containerfile lines 112–115 use `mios-sysext-pack.sh` to consolidate sysexts into `/usr/lib/extensions/source` — fine. No format break.

### 12.4 tmpfiles.d / sysusers.d
*Recorded 2026-05-11.*

- Stable. systemd 258/259 ship existing directives unchanged.
- Background: `sysusers.d/systemd-imdsd.service` (2026-03-26), `tmpfiles.d/root.conf` meson plumbing (2026-04-09).
- **CVE-2026-3888** — snap-confine + systemd-tmpfiles interaction → local privilege escalation to root (CVSS 7.8). Not a direct systemd bug — leveraged by snap-confine. MiOS does not ship snapd, so direct exposure is nil. Mentioned only as a general reminder to never create world-writable trees in user-controlled paths via tmpfiles.

### 12.5 bootc switch / upgrade / rollback + greenboot
*Recorded 2026-05-11.*

- `bootc switch` and `bootc upgrade` are semantically equivalent except switch changes the tracked image ref; both preserve `/etc` and `/var`.
- Blue/green deployments: management agent calls `bootc switch` (or declarative `bootc edit`).
- **`bootc rollback`** reorders bootloader entries; **changes to `/etc` do NOT carry into the rolled-back deployment** — they revert to that deployment's state.
- **`greenboot-rs`** (Rust rewrite) is the current Fedora track for boot-health verification. Required vs. wanted health-check scripts; failed required checks trigger reboot + auto-rollback.
- **Sharp edge:** Issue #946 — rollback after a `bootc switch` can leave the rollback deployment as default; verify before relying on it as Day-2 recovery contract.
- **Project status:** `automation/46-greenboot.sh` exists.

### 12.6 bootc CI build (image-builder action + cosign + buildkit)
*Recorded 2026-05-11.*

- **Upstream action:** **`osbuild/bootc-image-builder-action`** (ublue-os's wrapper is in maintenance — migrate).
- bootc-image-builder needs `--privileged` + `--security-opt label=type:unconfined_t`. GitHub-hosted runners grant that for a Docker-based privileged container, **but rootful BuildKit (`docker buildx` with `--privileged` worker) is the missing piece for LBI pre-pull** — this matches the project's reason for disabling it in the Containerfile.
- **cosign-installer@v3** is the current action; pair with `actions/attest-build-provenance` for SLSA. **cosign v3 requires `--bundle` in some flows.**

---

## Closing note

This file was bootstrapped 2026-05-11. Subsequent passes should **edit in place** — find the relevant subsection, update the data point, and add `(updated YYYY-MM-DD: <reason>)` inline. Use new dated subsections under a topic when a finding doesn't replace existing material. Remove proven-false content and note the removal in `ai-journal.md`.

**Iterations:**
- 2026-05-11 — bootstrap, 12 topic groups (`scheduled-research-daily`).
- 2026-05-16 — daily pass: NVIDIA LTS floor bumped (580.126.20 → 580.159.04), Podman 6.0 GA imminent, `image-builder-cli` v64 GA-ed bootc subcommand, K3s v1.34.8-rc1 + v1.35.5-rc1 + v1.36.0, etcd 3.5.30, WSL 2.7.5, Renovate 43.181.0, systemd 260 (correction — already shipped 2026-03-17), bsherman/ucore-hci now 404, CVE-2026-31431 reclassified to Linux kernel (corrected mis-attribution in §7.1), §6.5 added for May 2026 kernel CVE cluster.
- 2026-05-18 — daily pass: **Podman 6.0 GA SLIPPED to F45** (was "week of 2026-05-25" — Fedora change retargeted, no RC tag cut); kernel CVE cluster expanded from 5 → ~12 (AMDGPU cluster CVE-2026-43318/43305/43398/43400/43298/43237/43320 + Fragnesia CVE-2026-46300); kernel 6.18.28/6.18.30 and 6.12.87/6.12.88 noted as backport carriers; ucore-hci daily-rebuild cadence appears stalled (last tag 2026-05-11, 7 days old) — issues #385 + #362 still open; NVIDIA 595.44.08 Vulkan dev-beta (2026-05-15) added with branch-split clarification; stale baselines corrected — Mesa 25.3.4 → 26.1.0, QEMU 10.2.0 → 11.0.0, libvirt 12.1.0 → 12.3.0, fapolicyd 1.3.8 → 1.4.5; CrowdSec 1.7.8 (2026-05-11) added; Pacemaker 3.0.2-rc2 (2026-05-11) added; GNOME 50.2 (2026-05-23) noted; Renovate 43.182.4 (2026-05-18); K3s v1.34.8 GA still pending with CVE-2026-33186 grpc-go bump still uncalled-out; Secure Boot shim-16.1-6 unchanged in F44 stable, next checkpoint 2026-06-05; image-builder-cli format parity softened (only qcow2 + bootc-installer ISO documented).
