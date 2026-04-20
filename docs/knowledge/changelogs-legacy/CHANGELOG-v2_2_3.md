# CloudWS-bootc v0.1.8 - Consolidate into PACKAGES.md

## What went wrong

v2.2.0 shipped `PACKAGES-UNIFIED-EXTRAS.md` as a separate file alongside
`PACKAGES.md`. v2.2.2 added `scripts/51-install-unified-packages.sh` as a
parallel installer. Both violated the project's own principle:

> **PACKAGES.md is the single source of truth for all packages, parsed via
> fenced code blocks by `scripts/lib/packages.sh`.**

Two files + two installers = two sources of truth. Wrong.

## Fix

One file. One installer. Re-running this script is idempotent.

### Changes

- **Merge** every package from `PACKAGES-UNIFIED-EXTRAS.md` INTO `PACKAGES.md`
  between idempotent markers:

  ```
  <!-- CLOUDWS_V2_ADDITIONS_BEGIN -->
  ... (all v2.2+ additions as fenced blocks) ...
  <!-- CLOUDWS_V2_ADDITIONS_END -->
  ```

- **Delete** `PACKAGES-UNIFIED-EXTRAS.md` (content now in PACKAGES.md).

- **Delete** `scripts/51-install-unified-packages.sh` (was duplicating
  `scripts/lib/packages.sh`).

- **Rename** `scripts/50-install-repos.sh` -> `scripts/05-enable-external-repos.sh`
  so external repos (RPM Fusion, ublue COPR, bazzite-org COPR, hikariknight
  COPR, packagecloud CrowdSec, Rancher k3s-selinux) are enabled EARLY in the
  glob order - before `scripts/lib/packages.sh` tries to resolve their
  packages.

- **Create** `scripts/build.sh` (if missing) - minimal orchestrator that
  runs numbered scripts in order and invokes `lib/packages.sh`.

- **Create** `scripts/lib/packages.sh` (if missing) - minimal parser that
  extracts all fenced-block packages from PACKAGES.md and installs via
  dnf5, with automatic per-package fallback if the bulk transaction fails.

### Kept unchanged

- `scripts/52-bake-kvmfr.sh` - builds kvmfr.ko against the ucore-hci kernel
- `scripts/53-bake-lookingglass-client.sh` - compiles Looking Glass B7 client
- All v2.2.0 system_files, Containerfile, bib-configs, .github/workflows

These are BUILD STEPS (compile/bake), not package installs - they belong in
`scripts/` as numbered steps, not in `PACKAGES.md`.

## Idempotency

Running this script multiple times is safe:

1. PACKAGES.md: any existing `CLOUDWS_V2_ADDITIONS_BEGIN/END` block is
   stripped before the fresh one is appended.
2. File deletes: `git rm -f` silently succeeds on already-gone files.
3. File renames: guarded with `Test-Path` - only renamed if old exists
   and new does not.
4. build.sh / lib/packages.sh: only created if missing.

## How to verify the consolidation

After this push, in the container build:

```
[build] ==> 05-enable-external-repos.sh
[05-repos] Fedora version: 42
[05-repos] all external repos enabled
[build] ==> 40-composefs-verity.sh
[build] ==> 41-akmods-copy.sh
...
[build] ==> 53-bake-lookingglass-client.sh
[build] ==> lib/packages.sh (installing from PACKAGES.md)
[packages.sh] parsing /ctx/PACKAGES.md
[packages.sh] installing 147 unique packages
```

One source. One installer. Everything baked in.