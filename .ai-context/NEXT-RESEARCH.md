# NEXT-RESEARCH — agenda for 2026-04-21 (and beyond)

> Prepared by `scheduled-research-daily` at the end of the 2026-04-20 pass.
> Updated 2026-04-21 by Gemini CLI: Resolved high-priority items.

---

## ✅ RESOLVED — April 21, 2026

1. **GNOME 50 / F44 Readiness:** Verified `gnome-remote-desktop` + `grdctl` are in `docs/PACKAGES.md`. Legacy `xrdp`/`xorgxrdp` packages completely removed.
2. **Cosign Supply-Chain:** `sigstore/cosign-installer` pinned to `@v3.10.1` with `cosign-release: 'v2.6.3'` for absolute compatibility with `rpm-ostree/bootc`.
3. **NVIDIA 595.x Stability:** Injected `NVreg_UseKernelSuspendNotifiers=1` into `scripts/11-hardware.sh` to resolve Ada/Blackwell suspend issues.

---

## ACTION REQUIRED — flagged for Kabu

(All high-priority items resolved in April 21 pass.)

---

## Priority queue for 2026-04-21 (Updated)

Order reflects decreasing urgency:

### 1. bootc v1.16 / v1.15.x point releases
- monitor bootc-dev/bootc/releases for v1.15.2 or v1.16.0 blockers.
- Watch the composefs-native backend issue #1190 for rollback progress.

### 2. Waydroid / NVIDIA status
- Monitor `waydroid/waydroid` main branch for CDI-based device assignment work.
- Research Waydroid 1.5+ release for improved virtio-gpu on NVIDIA hosts.

### 3. CrowdSec v1.8.x watch
- Check crowdsecurity/crowdsec main branch for v1.8.0 timeline.

### 4. Podman 5.7 / Quadlet follow-ups
- Research Cockpit 349+ Quadlet GUI integration requirements.

### 5. Fedora 44 Konflux pipeline transition
- Watch for signature-verification failure reports post-F44 rebase due to GPG key chain changes.

---

## Upstream releases / CVE feeds to monitor (with links)

- **bootc releases:** https://github.com/bootc-dev/bootc/releases
- **bootc composefs-native meta-issue:** https://github.com/bootc-dev/bootc/issues/1190
- **rpm-ostree #5509 (cosign v3 bundle compat):** https://github.com/coreos/rpm-ostree/issues/5509
- **BIB WSL output request:** https://github.com/osbuild/bootc-image-builder/issues/172
- **nvidia-container-toolkit releases:** https://github.com/NVIDIA/nvidia-container-toolkit/releases
- **cosign releases:** https://github.com/sigstore/cosign/releases
- **Fedora 44 release schedule:** https://fedoraproject.org/wiki/Releases/44/Schedule
- **GNOME 50 post-release bugfix series:** https://release.gnome.org/50/
- **CrowdSec releases:** https://github.com/crowdsecurity/crowdsec/releases
- **Podman releases:** https://github.com/containers/podman/releases
- **WSL releases:** https://github.com/microsoft/WSL/releases
