# NEXT-RESEARCH — agenda for 2026-04-21 (and beyond)

> Prepared by `scheduled-research-daily` at the end of the 2026-04-20 pass.
> Tomorrow's run should read this file first, work through the topics in
> priority order, then iterate/rewrite this file for the day after.

---

## ACTION REQUIRED — flagged for Kabu

These are findings that imply a build-breaking or security-sensitive change.
**Do not auto-apply** — scheduled research is read-only outside `.ai-context/`.

1. **ACTION REQUIRED: Verify `gnome-remote-desktop` + `grdctl` are in `docs/PACKAGES.md` before the F43 → F44 rebase.**
   GNOME 50 (March 18, 2026) removed the X11 session entirely. The CLAUDE.md §3.4 warning against xRDP/xorgxrdp is now fully upstream-enforced — any CloudWS artifact that still ships `xrdp`, `xorgxrdp`, or `xorgxrdp-glamor` will either fail to build or ship a non-functional remote-desktop stack. Fedora 44 release target is **April 28, 2026**. Confirm:
   - `gnome-remote-desktop` package is present in `docs/PACKAGES.md` (section `packages-gnome` or similar).
   - No leftover `xrdp`/`xorgxrdp*` packages anywhere in the manifest.
   - `grdctl` provisioning is wired in (likely via `scripts/26-gnome-remote-desktop.sh` per `build.sh` skip-list in ai-journal April 21 entry).

2. **ACTION REQUIRED: Confirm `sigstore/cosign-installer` pin in `.github/workflows/build-sign.yml` resolves to cosign v2.6.3 (or v3.0.6+ with `--new-bundle-format=false`).**
   GHSA-w6c6-c85g-mmv6 (DSSE predicate validation) was fixed in cosign v2.6.3 and v3.0.6 on April 6, 2026. CloudWS should stay on the **v2.6.x** line because cosign v3's default protobuf bundle format is still incompatible with rpm-ostree/bootc signature verification (rpm-ostree#5509). If the workflow already pins v2.6.x, bump to v2.6.3 via Renovate. If it pins v3.x, either downgrade to v2.6.3 or ensure the sign step passes `cosign sign --new-bundle-format=false --yes $DIGEST`.

3. **ACTION REQUIRED (watch, not block): NVIDIA driver 595.58.03 is now the `stable-nvidia` default in ucore-hci (was 590.48.01).**
   The 590 → 595 bump happened within a week of NVIDIA's March 24, 2026 release. `image-versions.yml` digest-pin for `ghcr.io/ublue-os/ucore-hci:stable-nvidia` should be re-pinned on next Renovate PR so CloudWS-2 builds land on 595.58.03 deterministically. The new driver fixes a kernel-module build issue against Linux 6.19, which is the kernel in Fedora 44 — keep this in mind when F44 rebase testing begins.

---

## Priority queue for 2026-04-21

Order reflects decreasing urgency:

### 1. GNOME 50 / Fedora 44 deep-dive (rationale: F44 ships April 28; 8 days out)
- Read `release.gnome.org/50/` end-to-end and check for any additional X11-removal gotchas beyond xRDP (e.g., screenshare under xdg-desktop-portal, Waydroid compositor reqs).
- Check the Fedora 44 blocker bug list — if release slips further past April 28, CloudWS-1 rawhide testing should continue against what's effectively F45 now.
- Investigate `mutter` hw-accel build flags for RDP Vulkan path — is a non-default build option needed for the ucore-hci base image to emit hw-accelerated RDP? Check `ublue-os/main` PRs in the last 30 days.

### 2. bootc v1.16 / v1.15.x point releases (rationale: rapid release cadence continues)
- v1.15.1 shipped April 14, 2026 — monitor bootc-dev/bootc/releases for v1.15.2 or v1.16.0 blockers.
- Watch the composefs-native backend issue #1190 for rollback progress (currently the hard blocker on migrating CloudWS-2 to composefs-native).
- Watch for `bootc soft-reboot` landing in a stable F-series kernel — ucore-hci currently tracks F42 stable; F44 pivot will unlock soft-reboot evaluation.

### 3. cosign v3 protobuf bundle / rpm-ostree#5509 (rationale: long-running blocker)
- Check rpm-ostree#5509 for any comment/PR activity since mid-April 2026.
- If the issue is resolved upstream, plan the CloudWS cosign v3 migration path (would allow dropping the `--new-bundle-format=false` flag).
- Cross-check containers/image for the parallel fix.

### 4. NVIDIA container toolkit post-v1.19.0 (rationale: stale, but watched)
- v1.19.0 is from March 12, 2025 — it's been >12 months with no release. Check NVIDIA/nvidia-container-toolkit release notes, issues, and any pre-release tags for v1.19.1 or v1.20.0 work.
- Particularly: has the `After=multi-user.target` ordering bug been reverted/fixed? If yes, CloudWS's `10-cloudws-ordering.conf` drop-in becomes redundant (but harmless).

### 5. Universal Blue akmods pipeline (rationale: kernel drift risk)
- Linux 6.19 lands in F44 — check `ublue-os/akmods` for 6.19 kernel-module build validation.
- Verify that `akmods-nvidia-lts` (the new 580 LTS OCI artifact feeding `stable-nvidia-lts`) is actually being published to GHCR and stays current.
- Check whether `ucore-hci:stable-nvidia-lts` is a viable fallback if 595.x regresses on RTX 4090.

### 6. Waydroid / NVIDIA status (rationale: Section 3 note #7 long-standing)
- Is there any Waydroid 1.5+ release that improves NVIDIA Mesa virtio-gpu compatibility? Last research snapshot said no 3D acceleration on NVIDIA hosts.
- Monitor `waydroid/waydroid` main branch for CDI-based device assignment work.

### 7. CrowdSec v1.8.x watch (rationale: upstream is on 1.7.x, 1.8 may be close)
- Check crowdsecurity/crowdsec main branch and milestones for a v1.8.0 timeline.
- Does v1.7.7+ introduce any `acquis.yaml` or parser syntax changes that would affect the CloudWS `cloudws-crowdsec.service` provisioning?

### 8. Podman 5.7 / Quadlet follow-ups (rationale: 5.6 added significant keys)
- Has Podman 5.7 shipped yet? What's in the pipeline?
- Does Cockpit 349+ Quadlet GUI (mentioned in Red Hat Developers April 2026) need any CloudWS-side wiring?

### 9. K3s v1.34.x SELinux on bootc (rationale: ongoing integration pain)
- k3s-io/k3s#13710 — k3s-uninstall.sh calls `yum`/`dnf` which is read-only on bootc. Likely not applicable to CloudWS (we don't uninstall k3s via that script), but worth verifying `19-k3s-selinux.sh` doesn't hit the same class of bug.
- Check K3s v1.34.7 release notes for opencontainers/selinux dep bumps.

### 10. systemd 260 + cgroupv1 finality (rationale: F44 ships systemd 260)
- systemd 260 is in upstream — verify no CloudWS service unit accidentally depends on cgroupv1 controllers or SysV init compatibility shims.
- Pay attention to any systemd 260 → 261 regression list published post-F44 beta testing.

---

## Upstream releases / CVE feeds to monitor (with links)

- **bootc releases:** https://github.com/bootc-dev/bootc/releases (watch for v1.15.2, v1.16.0)
- **bootc composefs-native meta-issue:** https://github.com/bootc-dev/bootc/issues/1190
- **rpm-ostree #5509 (cosign v3 bundle compat):** https://github.com/coreos/rpm-ostree/issues/5509
- **BIB WSL output request:** https://github.com/osbuild/bootc-image-builder/issues/172
- **nvidia-container-toolkit releases:** https://github.com/NVIDIA/nvidia-container-toolkit/releases
- **nvidia-container-toolkit issue tracker:** https://github.com/NVIDIA/nvidia-container-toolkit/issues/1735 (`After=multi-user.target` bug)
- **cosign releases:** https://github.com/sigstore/cosign/releases (watch for v3.0.7+ and v2.6.4+)
- **Universal Blue ucore tags:** https://github.com/ublue-os/ucore/pkgs/container/ucore-hci
- **Fedora 44 release schedule:** https://fedoraproject.org/wiki/Releases/44/Schedule
- **GNOME 50 post-release bugfix series:** https://release.gnome.org/50/
- **CrowdSec releases:** https://github.com/crowdsecurity/crowdsec/releases
- **Podman releases:** https://github.com/containers/podman/releases
- **WSL releases:** https://github.com/microsoft/WSL/releases
- **CVE feeds:** NVD search for `nvidia-container-toolkit`, `cosign`, `podman`, `rpm-ostree`, `bootc`, `crowdsec`, `k3s`

---

## Follow-up questions raised today (not yet investigated)

1. Does `gnome-remote-desktop` in Fedora 42 stable (the ucore-hci `stable` base) already have the Vulkan/VA-API hw-accel code, or is that GNOME 50 / F44 only? If 50-only, CloudWS-2 does not get hw-accelerated RDP until the F44 rebase — which means users on CloudWS-2 today have a meaningfully degraded RDP experience vs. what will be available post-F44.
2. Is there any way to opt into `composefs-native` experimentally via a kargs/prepare-root flag while staying on the OSTree backend for production rollback? The two appear mutually exclusive, but worth re-reading the bootc.dev docs.
3. Are there known interactions between the Podman 5.6 `.image Policy=newer` key and bootc's logically-bound image pre-fetch? I.e., if bootc pre-fetches an image and Quadlet then runs with `Policy=newer`, does that cause a redundant pull? Seems likely, and might warrant a `Policy=missing` recommendation for logically-bound images.
4. ucore-hci `stable-nvidia-lts` (NVIDIA 580) vs. `stable-nvidia` (NVIDIA 595) — which one is the right long-term target for CloudWS-2 primary? The 590 → 595 rapid rollover is evidence that the non-LTS stream is aggressive. If Kabu wants stability over cutting-edge features, evaluate rebasing CloudWS-2 onto `stable-nvidia-lts`.
5. Fedora 44 Konflux pipeline transition — does it change the GPG signing key chain on `quay.io/fedora/fedora-bootc:rawhide`? If so, the `/etc/containers/policy.json` Fulcio/Rekor configuration may need a matching update to avoid signature-verification failures post-F44.

---

## Rationale summary (why this order)

Items 1–3 above are the **ACTION REQUIRED** flags — they directly gate the F44 upgrade path and the cosign security fix. Items 1–3 in the priority queue are the next-highest-urgency research threads because F44 is 8 days out (April 28, 2026) and will cascade changes through the entire CloudWS-2 stack. Items 4–7 are watching items that don't block but are worth periodic re-check. Items 8–10 are longer-horizon items where upstream movement is slower.
