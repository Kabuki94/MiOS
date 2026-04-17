# README Addendum — Documentation Links

Add this section to the main `README.md` to link all new documentation files.

---

## Documentation

| Document | Description |
|----------|-------------|
| [CHANGELOG.md](../CHANGELOG.md) | Version history in Keep a Changelog format |
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

The GitHub Actions pipeline automatically builds, tests, signs, and pushes CloudWS images:

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
./tests/smoke-test.sh localhost/cloudws-bootc:dev
```

The smoke test validates: OCI labels, bootc container lint, 14 critical packages, footgun absence, systemd service enablement, filesystem structure, security hardening files, GPU drivers, Flatpak remotes, and version info.
