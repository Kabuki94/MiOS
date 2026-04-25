# 🌐 MiOS — Universal AI Integration
> **Metadata:** proprietor: Kabu.ki, infrastructure: Self-Building Infrastructure (Personal Property), license: Licensed as personal property to Kabu.ki

---

# 🌐 MiOS — Universal AI Integration
> **Proprietor:** Kabu.ki
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to Kabu.ki
---
# NEXT-RESEARCH — agenda for 2026-04-26 (and beyond)

> Prepared by `scheduled-research-daily` at the end of the 2026-04-25 pass.
> Replaces the 2026-04-21 agenda.

---

## ✅ RESOLVED — April 25, 2026

1. **bootc v2.1.0 confirmed latest** — no v2.1.0/v2.1.0 cut; install-time issues #2130–#2132 catalogued.
2. **Podman v2.1.0 latest** — Quadlet 5.7/5.8 feature chain documented (Section 6).
3. **Cockpit 349+ Quadlet GUI** — feature progression documented (349 → 350 → 357 → 360 → 361).
4. **GNOME 50.1 NVIDIA Mutter regression** — fixed upstream April 15, 2026; F44 rebase will ship the fix automatically.
5. **cosign CVE-2026-39395** — CVE assignment confirmed; MiOS already pinned to v2.1.0.
6. **Waydroid + NVIDIA** — no CDI device-assignment path yet; status documented in new Section 14.

---

## 🚨 ACTION REQUIRED — flagged for Kabu

### A. CVE-2026-4631 — Cockpit unauthenticated RCE (CVSS 9.8) ⚠️ HIGH PRIORITY
- **Vector:** Remote-login SSH command-injection in Cockpit ≥327 / <360 paired with OpenSSH <9.6 → unauthenticated RCE on port 9090.
- **Fix:** Cockpit 360 (Apr 8, 2026) and backports 360.1 / 356.1.
- **MiOS exposure depends on:** which Cockpit version ucore-hci `stable-nvidia` is currently installing on top of Fedora 42. F44 rebase (April 28) clears the entire risk window.
- **Recommended pre-rebase mitigations** (in `system_files/usr/lib/cockpit/cockpit.conf` or `/etc/cockpit/cockpit.conf`):
  ```
  [WebService]
  LoginTo = false
  ```
  Plus: confirm OpenSSH ≥ 9.6 in `99-postcheck.sh`; firewalld restrict port 9090 to trusted nets.
- **DO NOT apply in this research pass** — research-only role. Hand off to Kabu / a build-side agent.

### B. WSL v2.1.0 CVE-2026-32178 — .NET SMTP header-injection
- Severity: **CVSS 7.5** (System.Net.Mail CRLF injection).
- WSL pre-release dropped 2026-04-25; will roll to the stable channel imminently.
- No MiOS image change needed — vuln is in WSL host runtime — but document the upgrade requirement in `docs/WSL2-DEPLOYMENT.md` once a build-side agent is invoked.

### C. F44 base rebase (April 28, 2026)
- Fedora 44 GA in 3 days. Konflux now drives bootc artifact builds.
- **Pre-rebase smoke checklist** (for Kabu / build agent):
  - Verify `cosign-installer` workflow pin still resolves to v2.1.0 post-Fedora-key-rotation.
  - Run `bootc container lint` on a F44-based test image to catch any new lint warnings (especially the kargs.d schema strict-validation that arrived in v1.14+).
  - Snapshot `image-versions.yml` digests before/after rebase for diff audit.
  - Re-test BIB qcow2/raw/vhd/anaconda-iso outputs once F44 base lands.

---

## Priority queue for 2026-04-26

Order reflects decreasing urgency.

### 1. Post-F44-rebase upstream verification (Apr 28, 2026)
- Watch GHCR base image digests (`ghcr.io/ublue-os/ucore-hci:stable-nvidia` + `quay.io/fedora/fedora-bootc:42`/`:rawhide`) for the F44 cutover window.
- Check Konflux signing-key chain: any `containers/policy.json` Fulcio root rotation? Look at `https://discussion.fedoraproject.org/t/f44-change-proposal-using-konflux-for-bootc-based-artifacts-selfcontained/179522`.
- Verify Cockpit version delivered by F44 base is ≥ 360.

### 2. bootc v2.1.0 / v2.1.0 release watch
- Monitor https://github.com/bootc-dev/bootc/releases for any new tag.
- Track #2132 + #2131 (composefs+UKI ESP/BIOS partition) — relevant when MiOS adopts UKI.

### 3. NVIDIA stack health check
- nvidia-container-toolkit appears stalled at v2.1.0 (Mar 2026). Search for any v1.19.x patch RCs or v1.20 schedule.
- NVIDIA driver 595.x → 600 series rumor watch (Blackwell stability).

### 4. Cockpit-podman / Cockpit ≥ 362 watch
- Cockpit cadence is ~weekly. Confirm 362+ does not regress Quadlet management features.

### 5. Waydroid CDI / virtio-gpu issue #1883
- Track waydroid/waydroid#1883 + #1234 for any actual upstream CDI/virgl progress.

### 6. CrowdSec — demoted to monthly cadence
- Still v2.1.0 (March 2025). Revisit only if v2.1.0 RC announced or new CVE filed.

### 7. Renovate config migration (low-priority cleanup)
- `stabilityDays` → `minimumReleaseAge: "N days"` migration for forward compatibility (already noted in Section 11).

---

## Upstream releases / CVE feeds to monitor (with links)

- **bootc releases:** https://github.com/bootc-dev/bootc/releases
- **bootc composefs-native meta-issue (#1190):** https://github.com/bootc-dev/bootc/issues/1190
- **bootc install-time issues (#2122/#2130/#2131/#2132/#2137):** https://github.com/bootc-dev/bootc/issues
- **rpm-ostree #5509 (cosign v3 bundle compat):** https://github.com/coreos/rpm-ostree/issues/5509
- **BIB WSL output request (#172):** https://github.com/osbuild/bootc-image-builder/issues/172
- **nvidia-container-toolkit releases:** https://github.com/NVIDIA/nvidia-container-toolkit/releases
- **cosign releases:** https://github.com/sigstore/cosign/releases
- **cosign GHSA-w6c6-c85g-mmv6 / CVE-2026-39395:** https://github.com/sigstore/cosign/security/advisories/GHSA-w6c6-c85g-mmv6
- **Cockpit releases:** https://cockpit-project.org/blog/
- **Cockpit CVE-2026-4631 advisory:** https://github.com/advisories/GHSA-rq49-h582-83m7
- **Cockpit CVE-2026-4631 RHSA:** https://access.redhat.com/security/cve/cve-2026-4631
- **Fedora 44 release status:** https://fedorapeople.org/groups/schedule/f-44/f-44-key-tasks.html
- **Fedora 44 Konflux change proposal:** https://discussion.fedoraproject.org/t/f44-change-proposal-using-konflux-for-bootc-based-artifacts-selfcontained/179522
- **GNOME 50.x bugfix series:** https://release.gnome.org/50/
- **CrowdSec releases:** https://github.com/crowdsecurity/crowdsec/releases
- **Podman releases:** https://github.com/containers/podman/releases
- **WSL releases:** https://github.com/microsoft/WSL/releases
- **CVE-2026-32178 (WSL .NET SMTP injection):** https://msrc.microsoft.com/update-guide/vulnerability/CVE-2026-32178
- **Waydroid NVIDIA issue #1883:** https://github.com/waydroid/waydroid/issues/1883

---

## Rationale for priority order

1. **F44 rebase** is in 3 days; missing this window risks shipping a Cockpit version still vulnerable to CVE-2026-4631. Highest urgency.
2. **bootc release watch** is structurally important — any new tag may resolve install-time issues or change kargs.d/composefs semantics that MiOS depends on.
3. **NVIDIA stack** stagnation is a yellow flag for downstream image rebuilds; needs surveillance.
4. **Cockpit weekly cadence** generates the most upstream churn; check after the F44 rebase clears the CVE.
5. **Waydroid** is genuinely stalled; monthly cadence is fine.
6. **CrowdSec** 12-month silence on a major version means it's no longer "imminent"; demote to monthly check.
7. **Renovate cleanup** is purely housekeeping; do it whenever someone touches `renovate.json` next.

---
### 📚 Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osbuild/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [Kabuki94/MiOS](https://github.com/Kabuki94/MiOS)
- **Sole Proprietor:** Kabu.ki
---
