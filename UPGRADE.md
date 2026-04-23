# Upgrade & Rollback Guide

CloudWS-bootc uses `bootc` for atomic, image-based system updates. Every upgrade downloads a new OCI image, stages it alongside the current deployment, and switches to it on reboot. If anything goes wrong, you can roll back to the previous deployment instantly.

## How Updates Work

CloudWS is an immutable OS delivered as an OCI container image. The system root (`/usr`) is read-only and managed entirely by bootc. Your data in `/var` (which includes `/var/home`, symlinked from `/home`) and your modifications in `/etc` are preserved across updates. The update process is:

1. `bootc` pulls the new image from `ghcr.io/kabuki94/cloudws-bootc:latest`
2. The new image is staged as a second deployment
3. On reboot, GRUB switches to the new deployment
4. The previous deployment is kept as a rollback target

## Checking for Updates

```bash
# Check if an update is available (does NOT apply it)
sudo bootc upgrade --check
```

This compares your running image digest against the registry and reports whether a newer image exists.

## Performing an Upgrade

```bash
# Download and stage the new image
sudo bootc upgrade

# Reboot into the new deployment
sudo systemctl reboot
```

After reboot, verify the update applied:

```bash
# Show current and previous deployments
sudo bootc status

# Confirm running version
cat /etc/cloudws-version
```

## Automatic Updates

CloudWS ships with `podman-auto-update.timer` enabled for container workloads. For the OS itself, automatic `bootc upgrade` can be configured via a systemd timer:

```bash
# Check if the auto-update timer is active
systemctl status bootc-fetch-apply-updates.timer
```

If you prefer manual control, leave the timer disabled and run `sudo bootc upgrade` on your own schedule.

## Rolling Back

If an upgrade causes problems, roll back to the previous deployment:

```bash
# Switch back to the previous deployment
sudo bootc rollback

# Reboot into the rolled-back deployment
sudo systemctl reboot
```

After reboot, confirm you're on the previous version:

```bash
sudo bootc status
```

The rollback is instant — it simply changes which deployment GRUB boots into. No download is required.

## Switching Images

To switch from one CloudWS variant to another (or to a specific tagged version):

```bash
# Switch to a specific tag
sudo bootc switch ghcr.io/kabuki94/cloudws-bootc:v1.3.0

# Switch to the ucore-based variant (when available)
sudo bootc switch ghcr.io/kabuki94/cloudws-bootc:ucore
```

## What Gets Preserved

| Path | Behavior |
|------|----------|
| `/var` (includes `/var/home`) | Fully persistent across upgrades |
| `/etc` | Persistent with 3-way merge — your local changes are kept, new defaults from the image are added, conflicts are flagged |
| `/usr` | Replaced entirely by the new image (immutable) |
| Flatpak apps | Independent of the OS image — managed separately |
| Podman containers | Independent — quadlet units in `/etc/containers/systemd/` persist |

## Troubleshooting

### Upgrade fails to download

```bash
# Check network connectivity to GHCR
curl -sI https://ghcr.io/v2/ | head -5

# Check authentication (if using a private image)
podman login ghcr.io

# Retry with verbose output
sudo bootc upgrade 2>&1 | tee /tmp/bootc-upgrade.log
```

### System won't boot after upgrade

1. At the GRUB menu, select the previous deployment entry
2. Once booted, run `sudo bootc rollback` to make the rollback permanent
3. File a bug report with the output of `journalctl -b -1` (previous boot's journal)

### Verifying image signatures

CloudWS images are signed with cosign. To verify:

```bash
cosign verify \
  --certificate-identity-regexp="https://github.com/Kabuki94/CloudWS-bootc" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/kabuki94/cloudws-bootc:latest
```

**Known limitation**: bootc's `--enforce-container-sigpolicy` flag works on `bootc switch` and `bootc install` but does not yet enforce on `bootc upgrade` (upstream issue #528).

### Checking disk space before upgrade

Upgrades require enough space in the boot partition and in the sysroot for a second deployment. Check available space:

```bash
df -h /boot /sysroot
```

A typical CloudWS image requires approximately 8–12 GB for each deployment.

## Downgrading to a Specific Version

If you need to go back further than the immediate previous deployment:

```bash
# Pin to a specific version by digest
sudo bootc switch ghcr.io/kabuki94/cloudws-bootc@sha256:<digest>
sudo systemctl reboot
```

Find available digests on the GHCR package page or via:

```bash
skopeo list-tags docker://ghcr.io/kabuki94/cloudws-bootc
```
