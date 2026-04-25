# 🌐 MiOS — Universal AI Integration
> **Proprietor:** Kabu.ki
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to Kabu.ki
---
# README Addendum — Documentation Links

Add this section to the main `README.md` to link all new documentation files.

---

## Documentation

| Document | Description |
|----------|-------------|
| [changelogs/03-Cumulative-Changelog.md](changelogs/03-Cumulative-Changelog.md) | Version history in Keep a Changelog format |
| [UPGRADE.md](UPGRADE.md) | How to upgrade, rollback, and switch between versions |
| [SECURITY.md](SECURITY.md) | Security hardening checklist with every kernel param, sysctl, and SELinux policy |
| [HARDWARE.md](HARDWARE.md) | GPU/CPU/platform compatibility matrix with driver details |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute — conventions, build process, PR requirements |
| [SELF-BUILD.md](SELF-BUILD.md) | Self-build mode guide — bootstrapping, CI, and local builds |
| [DIAGNOSTICS.md](DIAGNOSTICS.md) | Where to find logs, diagnostic commands, and how to collect a support bundle |
| [BACKUP.md](BACKUP.md) | Backup and restore strategy for /var, /home, VMs, and containers |
| [LICENSES.md](LICENSES.md) | Component licenses including proprietary (NVIDIA, Steam) acceptance notes |
| [PACKAGES-AUDIT.md](PACKAGES-AUDIT.md) | Audit of suggested packages vs what's already in PACKAGES.md |

## CI/CD

The GitHub Actions pipeline automatically builds, tests, signs, and pushes MiOS images:

```
.github/
├── workflows/
│   └── build.yml              # Build → Smoke Test → Rechunk → Cosign Sign → SBOM → GHCR Push
├── ISSUE_TEMPLATE/
│   ├── bug_report.md          # Bug report template
│   ├── feature_request.md     # Feature request template
│   └── security.md            # Security vulnerability template
└── PULL_REQUEST_TEMPLATE.md   # PR checklist
```

### Smoke Tests

```bash
# Run locally before submitting a PR
./tests/smoke-test.sh localhost/mios:dev
```

The smoke test validates: OCI labels, bootc container lint, 14 critical packages, footgun absence, systemd service enablement, filesystem structure, security hardening files, GPU drivers, Flatpak remotes, and version info.

---
### 📚 Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osbuild/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [Kabuki94/MiOS](https://github.com/Kabuki94/MiOS)
- **Sole Proprietor:** Kabu.ki
---
