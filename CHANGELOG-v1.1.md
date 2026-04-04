# CloudWS v1.1 Changelog — Boot Fix + GNOME Updates + Security Fix

## Critical Fixes

### 1. Hyper-V Boot Hang (60-90+ second delays → instant)

**Root cause:** Services that only make sense on bare metal (NFS server, Pacemaker/Corosync, CrowdSec, multipathd) were starting unconditionally. In VMs they either timeout waiting for hardware that doesn't exist or block on network-online.target.

**Fix:** `scripts/20-services.sh` now creates `ConditionVirtualization=no` drop-in files for all bare-metal-only services. systemd evaluates this at service start time — in any VM (Hyper-V, QEMU, VMware), the service is silently skipped with status "skipped" (not "failed"). On bare metal, everything starts normally.

**Services gated to bare-metal-only:**
- `nfs-server` (was waiting 60s for network + RPC registration)
- `smb`, `nmb` (Samba — pointless in VMs)
- `pacemaker`, `corosync`, `pcsd` (HA clustering — fails without cluster interfaces)
- `crowdsec`, `crowdsec-firewall-bouncer` (IPS — needs nftables, absent in WSL2)
- `multipathd` (SAN multipath — no physical disks in VMs)
- `osbuild-composer` (image builder — bare-metal dev tool)

**Files changed:** `scripts/20-services.sh`

### 2. GNOME Software Not Showing OS Updates

**Root cause:** BIB was building disk images from `localhost/cloudws:latest`. This localhost reference becomes the permanent update origin baked into the deployed system. `bootc upgrade` tries to contact a registry at `localhost` — which doesn't exist.

**Fix (three parts):**

1. **`cloud-ws.ps1`**: Image is now tagged with the GHCR ref (`ghcr.io/kabuki94/cloudws-bootc:latest`) BEFORE BIB runs. BIB resolves the image from local storage (via the volume mount) but records the GHCR URL as the update origin.

2. **`Containerfile`**: Added `gnome-software-rpm-ostree` package install. Without this, GNOME Software only shows Flatpak updates — it has no pathway to discover OS-level bootc updates. The rpm-ostree D-Bus daemon acts as a bridge to bootc.

3. **`Justfile`**: Same GHCR ref fix for Linux-native builds.

**`--local` flag removed:** BIB now defaults to local behavior. The flag was causing a harmless warning but was confusing.

**For already-deployed systems:** Run `sudo bootc switch ghcr.io/kabuki94/cloudws-bootc:latest` to fix the update origin without reinstalling. All `/etc` and `/var` state (home dirs, SSH keys, configs) is preserved.

**Files changed:** `cloud-ws.ps1`, `Containerfile`, `Justfile`

### 3. PAT/Token Leaked in Terminal Output

**Root cause:** Registry token was passed as a command-line argument to `podman login`, which appears in full in the terminal scrollback and potentially in process listings.

**Fix:** Token is now piped via `--password-stdin`:
```powershell
$RegistryToken | podman login $registryHost --username $RegistryUser --password-stdin
```

**IMMEDIATE ACTION REQUIRED:** Rotate the leaked PAT at:
GitHub → Settings → Developer settings → Personal access tokens

**Files changed:** `cloud-ws.ps1`

### 4. VM Service Masking Rewritten

**Root cause:** The old `cloudws-vm-mask.service` ran `systemctl mask --now` during early boot. This raced with service startup — services could begin initializing before the mask took effect.

**Fix:** `scripts/99-overrides.sh` section 15 rewritten. Instead of runtime masking:
- `gdm`: Skip in WSL2 only (via `ConditionPathExists=!/proc/sys/fs/binfmt_misc/WSLInterop`). Hyper-V VMs with hyperv_drm framebuffer SHOULD run GDM.
- `nvidia-powerd`: `ConditionVirtualization=no` (no physical GPU in VMs)
- `waydroid-container`, `dev-binderfs.mount`: Skip in WSL2 only (no binder support)

**Files changed:** `scripts/99-overrides.sh`

### 5. Hyper-V Configuration Reminder Added

The build report now includes a reminder about critical Hyper-V Gen2 VM settings:
- **Secure Boot template:** Must be "Microsoft UEFI Certificate Authority" (NOT "Microsoft Windows")
- **Dynamic Memory:** Disable or set minimum RAM ≥ 4096 MB (hv_balloon causes boot stalls)

**Files changed:** `cloud-ws.ps1`

## Files Modified (5 total — drop-in replacements)

| File | Lines | Changes |
|------|-------|---------|
| `cloud-ws.ps1` | 341 | PAT stdin fix, GHCR tag before BIB, --local removed, Hyper-V hints |
| `Containerfile` | 46 | gnome-software-rpm-ostree install |
| `Justfile` | 97 | GHCR ref for BIB, --local removed, switch target added |
| `scripts/20-services.sh` | 70 | ConditionVirtualization=no drop-ins for bare-metal services |
| `scripts/99-overrides.sh` | 659 | Section 15 rewritten: drop-ins replace runtime masking, cloudws-update improved |

## Verification Commands (run on deployed system)

```bash
# Check service skip status in VM
systemd-detect-virt                    # "microsoft" on Hyper-V
systemctl status nfs-server            # Should show "Condition: start condition unmet"
systemctl status pacemaker             # Same — skipped cleanly

# Check update origin
bootc status                           # Image should show ghcr.io/... not localhost
bootc upgrade                          # Should check GHCR for new images

# Check GNOME Software plugin
rpm -q gnome-software-rpm-ostree       # Should be installed
```
