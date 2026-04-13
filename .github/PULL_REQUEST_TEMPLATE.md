## Summary

Brief description of what this PR does.

## Type of change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to change)
- [ ] Documentation update
- [ ] Build system / CI change
- [ ] Security hardening

## Changes

Describe the changes in detail.

## Testing

Describe how you tested these changes:

- [ ] Local `podman build` succeeds
- [ ] `bootc container lint` passes
- [ ] Tested boot on: (bare metal / Hyper-V / WSL2 / QEMU)
- [ ] Verified GPU detection works
- [ ] Verified affected services start correctly
- [ ] SELinux denials checked (`ausearch -m AVC -ts recent`)

## Checklist

- [ ] PACKAGES.md updated (if packages changed)
- [ ] VERSION bumped (if user-facing change)
- [ ] CHANGELOG updated
- [ ] No files removed without explicit maintainer approval
- [ ] Complete drop-in files provided (no patches, diffs, or fragments)
- [ ] `set -euo pipefail` used in all scripts
- [ ] Arithmetic uses `VAR=$((VAR + 1))` (never `((VAR++))`)
- [ ] `/etc/skel` files written before `useradd -m`
