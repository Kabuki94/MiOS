# Backup & Restore Strategy

CloudWS-bootc is an immutable OS — the system root (`/usr`) is replaced entirely on each update. Your data lives in `/var` (which includes `/var/home`, symlinked from `/home`) and your configuration overrides in `/etc`. This document explains what to back up, how, and how to restore after a reinstallation or migration.

## What Needs Backing Up

| Path | Contains | Persistence |
|------|----------|-------------|
| `/var/home/` | User home directories, documents, configs | Survives upgrades, lost on reinstall |
| `/etc/` | System configuration overrides | Survives upgrades (3-way merge), lost on reinstall |
| `/var/lib/libvirt/` | VM disk images, snapshots, configs | Survives upgrades, lost on reinstall |
| `/var/lib/containers/` | Podman images, volumes, quadlet data | Survives upgrades, lost on reinstall |
| `/var/lib/crowdsec/` | CrowdSec sqlite database and data | Survives upgrades, lost on reinstall |
| `/var/lib/gnome-remote-desktop/` | RDP TLS certificates and keys | Survives upgrades, lost on reinstall |
| `/var/opt/` | Application data (symlinked from /opt) | Survives upgrades, lost on reinstall |
| `/etc/containers/systemd/` | Custom quadlet unit files | Survives upgrades, lost on reinstall |
| `/etc/usbguard/rules.conf` | USBGuard device allowlist | Survives upgrades, lost on reinstall |
| `/etc/fapolicyd/` | Application whitelisting rules | Survives upgrades, lost on reinstall |
| `/var/lib/rancher/k3s/` | K3s state, etcd data | Survives upgrades, lost on reinstall |

**You do NOT need to back up `/usr/`** — it is entirely defined by the OCI image and will be restored on any fresh deployment.

## What Does NOT Need Backing Up

- `/usr/` — immutable, defined by the container image
- Flatpak apps — reinstall from Flathub (`flatpak install` or via GNOME Software)
- Podman images (without volumes) — re-pull from registries
- System packages — defined in PACKAGES.md, baked into the image

## Recommended Backup Methods

### Simple: rsync to external drive or NFS

```bash
# Back up home directories
sudo rsync -aAXv /var/home/ /mnt/backup/home/

# Back up /etc overrides
sudo rsync -aAXv /etc/ /mnt/backup/etc/

# Back up VM images (can be very large)
sudo rsync -aAXv /var/lib/libvirt/ /mnt/backup/libvirt/

# Back up Podman volumes
sudo rsync -aAXv /var/lib/containers/storage/volumes/ /mnt/backup/podman-volumes/

# Back up K3s state
sudo rsync -aAXv /var/lib/rancher/k3s/ /mnt/backup/k3s/
```

### Scheduled: systemd timer + rsync

Create a backup timer that runs nightly:

```bash
# /etc/systemd/system/cloudws-backup.service
[Unit]
Description=CloudWS nightly backup
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/cloudws-backup.sh

# /etc/systemd/system/cloudws-backup.timer
[Unit]
Description=Run CloudWS backup nightly

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable with `sudo systemctl enable --now cloudws-backup.timer`.

### VM-specific: virsh snapshot

For libvirt VMs, use native snapshots:

```bash
# Create a snapshot
virsh snapshot-create-as --domain myvm --name "pre-upgrade" --description "Before CloudWS upgrade"

# List snapshots
virsh snapshot-list --domain myvm

# Restore a snapshot
virsh snapshot-revert --domain myvm --snapshotname "pre-upgrade"
```

### Podman volumes: export/import

```bash
# Export a named volume
podman volume export myvolume > myvolume-backup.tar

# Import into a new volume
podman volume create myvolume-restored
podman volume import myvolume-restored myvolume-backup.tar
```

## Restoring After Reinstallation

After deploying a fresh CloudWS image (via ISO, VHDX, WSL import, or OCI pull):

1. **Restore home directories:**
   ```bash
   sudo rsync -aAXv /mnt/backup/home/ /var/home/
   ```

2. **Restore /etc overrides** (selective — don't blindly overwrite):
   ```bash
   # Review what you backed up
   ls /mnt/backup/etc/

   # Restore specific configs
   sudo cp /mnt/backup/etc/usbguard/rules.conf /etc/usbguard/rules.conf
   sudo cp -r /mnt/backup/etc/containers/systemd/ /etc/containers/systemd/
   sudo cp -r /mnt/backup/etc/fapolicyd/ /etc/fapolicyd/
   ```

3. **Restore VM images:**
   ```bash
   sudo rsync -aAXv /mnt/backup/libvirt/ /var/lib/libvirt/
   sudo restorecon -Rv /var/lib/libvirt/
   ```

4. **Restore Podman volumes:**
   ```bash
   sudo rsync -aAXv /mnt/backup/podman-volumes/ /var/lib/containers/storage/volumes/
   ```

5. **Restore K3s state:**
   ```bash
   sudo rsync -aAXv /mnt/backup/k3s/ /var/lib/rancher/k3s/
   ```

6. **Restore SELinux labels** (critical after any rsync restore):
   ```bash
   sudo restorecon -Rv /var/home /var/lib/libvirt /var/lib/containers
   ```

7. **Reinstall Flatpak apps:**
   ```bash
   # If you exported the list before reinstall:
   flatpak install --assumeyes $(cat flatpak-list.txt)

   # Or manually:
   flatpak install flathub org.mozilla.firefox
   ```

   To create a Flatpak list for future restores:
   ```bash
   flatpak list --app --columns=application > flatpak-list.txt
   ```

## Migrating Between Machines

The same backup/restore process works for migration. Since CloudWS is image-based, deploy the same OCI image on the new machine, then restore your `/var` data.

```bash
# On the old machine: create a full backup
sudo tar czf /mnt/external/cloudws-migration.tar.gz \
  /var/home \
  /etc/containers/systemd \
  /etc/usbguard \
  /etc/fapolicyd \
  --exclude='/var/home/*/.cache' \
  --exclude='/var/home/*/.local/share/Trash'

# On the new machine: deploy CloudWS, then restore
sudo tar xzf /mnt/external/cloudws-migration.tar.gz -C /
sudo restorecon -Rv /var/home /etc
```

## LUKS Encryption Considerations

If your CloudWS installation uses LUKS+TPM2 (`bootc install to-disk --block-setup tpm2-luks`), the TPM binding is machine-specific. After migrating to new hardware:

```bash
# Re-enroll TPM2 on the new machine
sudo systemd-cryptenroll --wipe-slot tpm2 --tpm2-device auto /dev/disk/by-label/root
```

Keep your LUKS recovery passphrase stored securely — it's the only way to unlock the disk if TPM binding fails.
