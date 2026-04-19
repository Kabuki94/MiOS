# CloudWS Composefs Root Verification

## Overview

`cloudws-verify-root.service` runs after `ostree-remount.service` and before
`greenboot-healthcheck.service`. It validates the post-pivot root filesystem
using a three-tier strategy and wires into greenboot for automatic rollback.

## Chain of trust

```
UEFI firmware
  └─ shim (Microsoft-signed)
      └─ GRUB2 (shim-signed)
          └─ kernel + initrd (shim-signed or akmod-signed via MOK)
              └─ ostree/bootc pivot
                  └─ composefs mount (/usr — integrity against accidental mutation)
                      └─ cloudws-verify-root.service (Tier A/B/C checks)
                          └─ greenboot-healthcheck.service
                              └─ greenboot rollback if check fails
```

## Three-tier strategy

### Tier A — path existence (~22 paths)

Checks that all critical binaries, systemd units, and config files exist.
Always runs. Any missing path causes `exit 1`, which greenboot treats as a
failed health check and schedules a rollback.

Covered: bootc, podman, skopeo, crun, systemd, journald, logind, udevd,
gdm, cockpit.socket, `/usr/libexec/cloudws`, SELinux config, os-release,
kernel modules dir for the running kernel.

### Tier B — fsverity measure (advisory)

Reads `/usr/lib/cloudws/verify-root.digests` (format: `sha256-hash path`
one per line) and calls `fsverity measure` on each path.

**This tier is a no-op under default Fedora bootc configuration.** Fedora
bootc defaults to `composefs.enabled = yes` (unsigned) — composefs provides
integrity against accidental mutation, not against attackers with root.
`fsverity measure` returns a cached Merkle root; the measurement is constant-
time and cheap. But the measurement is only non-trivial if the filesystem was
built with fs-verity enabled (`composefs.enabled = verity` in
`/usr/lib/ostree/prepare-root.conf`).

To activate Tier B, ship `verify-root.digests` and enable composefs verity:

```
# /usr/lib/ostree/prepare-root.conf
[composefs]
enabled = verity
```

Tier B mismatches are logged as warnings, not errors — the intent is detection,
not hard blocking (Tier A + greenboot is the primary guard).

### Tier C — policy.json SHA-256

Compares `/etc/containers/policy.json` against the baseline SHA-256 stored in
`/usr/lib/cloudws/policy.json.sha256`. The baseline digest lives under `/usr`,
which is composefs-covered, so tampering with the digest would require
compromising the image itself.

`/etc/containers/policy.json` is the single highest-impact file for runtime
signature enforcement. Swapping it to `insecureAcceptAnything` silently
disables all image verification. Tier C catches this.

**False positive on legitimate edits**: if you deliberately change
`policy.json` (e.g. to add a new trusted registry), update the baseline:

```bash
sha256sum /etc/containers/policy.json | awk '{print $1}' \
  > system_files/usr/lib/cloudws/policy.json.sha256
# rebuild and push the image
```

## Greenboot wiring

`/etc/greenboot/check/required.d/10-cloudws-composefs.sh` is a thin wrapper
that invokes `verify-root.sh`. Greenboot will retry up to 3 times on failure,
then trigger `bootc rollback` (which reverts `/usr` and `/boot`; `/etc` is
3-way merged; `/var` persists).

## Why not IMA/EVM?

IMA/EVM is kernel-level per-file signature enforcement. It's overkill for
a workstation where the threat model is "accidental mutation or single-point
software supply chain compromise" rather than "persistent root-level attacker
who wants to hide". composefs + MOK-signed kernel is sufficient. The
fs-verity maintainer has discouraged in-kernel signature handling in favour
of userspace composefs (composefs/composefs#151).

## Escape hatch

If greenboot is causing a rollback loop due to a Tier C false positive:

```bash
# Boot to previous deployment, then:
sudo systemctl mask greenboot-healthcheck.service
# Fix the issue, update policy.json.sha256, rebuild image, push, bootc upgrade
sudo systemctl unmask greenboot-healthcheck.service
```

## /etc drift semantics

bootc 3-way merges `/etc` on upgrade (base changes + local changes = merged).
On `bootc rollback`, `/etc` reverts to the rolled-back deployment's state.
`/var` always persists unconditionally. The policy.json baseline in `/usr`
is composefs-covered (upgrade-safe); the live `policy.json` in `/etc` is
the one being checked (upgrade-merged).
