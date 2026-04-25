---
name: Bug Report
about: Report a bug in MiOS
title: "[BUG] "
labels: bug
assignees: Kabuki94
---

## Environment

- **MiOS version**: (run `cat /etc/mios-version` or `rpm-ostree status`)
- **Deployment method**: (Bare metal / Hyper-V VHDX / WSL2 / Anaconda ISO / OCI pull)
- **Hardware**:
  - CPU: 
  - GPU: 
  - RAM: 
- **Kernel**: (run `uname -r`)
- **NVIDIA driver**: (run `nvidia-smi --query-gpu=driver_version --format=csv,noheader` or N/A)

## Describe the bug

A clear description of what the bug is.

## Steps to reproduce

1. 
2. 
3. 

## Expected behavior

What you expected to happen.

## Actual behavior

What actually happened.

## Logs

Attach relevant logs. Useful commands:

```bash
# System journal (last boot)
journalctl -b -0 --no-pager | tail -200

# GPU auto-detect
journalctl -u mios-gpu-detect --no-pager

# Build log (if build failure)
cat /tmp/mios-build.log

# SELinux denials
ausearch -m AVC -ts recent
```

## Screenshots

If applicable, add screenshots.

## Additional context

Any other context about the problem.
