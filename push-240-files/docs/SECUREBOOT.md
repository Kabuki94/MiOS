# CloudWS Secure Boot & MOK Enrollment

## Signing chain

```
Microsoft UEFI CA (in firmware db)
  └─ Red Hat shim (signed by MS)
      └─ GRUB2 bootloader (shim-verified)
          └─ Fedora kernel (shim-verified, Red Hat key)
              └─ Out-of-tree kmods (verified via MOK)
```

CloudWS uses **GRUB2 + shim** (the Red Hat/Fedora default), not
systemd-boot or UKI. This means:

- **Use `mokutil`**, not `sbctl`. sbctl is for users who own the firmware
  PK/KEK/db chain (sd-boot/UKI path). It will not work here.
- UKI support is tracked in bootc#806 (opened 2024-09-27). When bootc
  officially supports UKI, CloudWS can migrate. Until then, GRUB2+shim.

## CloudWS-1 vs CloudWS-2

| Variant | Base | kmod signing |
|---|---|---|
| CloudWS-1 | `fedora-bootc:rawhide` | akmods builds local kmod, you enroll CloudWS MOK key |
| CloudWS-2 | `ucore-hci:stable-nvidia` | Universal Blue pre-signed NVIDIA kmods via `akmods-ublue.der` key |

For CloudWS-2, the ublue key at `/etc/pki/akmods/certs/akmods-ublue.der`
must be enrolled in MokManager. The key is NOT in the MS UEFI CA chain —
a one-time enrollment is still required.

`enroll-mok.sh` detects the variant automatically: it prefers
`/etc/pki/cloudws/mok.der` (CloudWS-1), falls back to
`/etc/pki/akmods/certs/akmods-ublue.der` (CloudWS-2).

## Generating a MOK key (CloudWS-1 only)

```bash
sudo scripts/generate-mok-key.sh
```

This creates a 2048-bit RSA key (NOT 4096 — 4096-bit keys hang some shim
versions) with a 10-year validity. The private key is encrypted; the DER
cert is placed at `/etc/pki/cloudws/mok.der`.

**Generate once, never per-build.** Regenerating the key means every
previous user must re-enroll. Store:
- `CLOUDWS_MOK_KEY_B64` → GitHub secret (base64-encoded encrypted PEM)
- `CLOUDWS_MOK_KEY_PASSWORD` → GitHub secret (passphrase)

Commit the DER cert only:
```bash
cp /etc/pki/cloudws/mok.der system_files/etc/pki/cloudws/mok.der
```

## Enrolling a key

```bash
sudo scripts/enroll-mok.sh
```

This script:
1. Checks if Secure Boot is enabled (exits cleanly if not).
2. Detects the appropriate key (CloudWS-1 or CloudWS-2 variant).
3. Checks if the key is already enrolled or pending (idempotent).
4. Queues the key via `mokutil --import --root-pw`.
5. Logs to `/var/log/cloudws/mok-enroll-<timestamp>.log`.

### MokManager UI

Reboot after running `enroll-mok.sh`. At the blue MokManager screen:

1. **Enroll MOK** → **Continue** → **Yes**
2. Enter the system root password (same as `sudo` password).
3. **Reboot**

MokManager requires **physical presence** — this cannot be automated by
design (prevents remote supply-chain attacks).

### Checking enrollment status

```bash
/usr/libexec/cloudws/mok-enroll-status
```

Emits one of: `enrolled | pending | not-enrolled | no-secureboot | conflict`

## TPM2 PCR7 re-seal warning

**EVERY MOK mutation changes TPM2 PCR 7.** If you have LUKS volumes sealed
to PCR 7 with `systemd-cryptenroll`, they will fail to auto-unlock after
the enrollment reboot.

After completing enrollment in MokManager, re-seal immediately:

```bash
# Wipe existing TPM2 slot
sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/sdaX

# Re-seal to PCR 7 (Secure Boot state) + PCR 14 (MOK state)
sudo systemd-cryptenroll \
  --tpm2-device=auto \
  --tpm2-pcrs=7+14 \
  /dev/sdaX
```

PCR 14 covers the MOK database. Sealing to both 7+14 means the key is
only released when both Secure Boot and the enrolled MOK are in their
expected states.

## Key rotation

To rotate a MOK key:
1. Generate a new key (`generate-mok-key.sh`).
2. Enroll the new key (`enroll-mok.sh`).
3. Delete the old key: `mokutil --delete /etc/pki/cloudws/mok.old.der`
4. Complete both operations in MokManager on the next reboot.
5. Re-seal TPM2 after both reboots complete.
6. Update `system_files/etc/pki/cloudws/mok.der`, rebuild, push image.

## Troubleshooting

**`mokutil: command not found`**
```bash
sudo dnf install mokutil
```

**MokManager doesn't appear after reboot**
- Secure Boot may be disabled in UEFI. Check `mokutil --sb-state`.
- Some boards require manual navigation to MokManager.

**`mokutil --timeout -1` fails silently**
Known issue on some ASUS H97i-class boards (ublue-os/bazzite#3030). The
enrollment still proceeds; the timeout setting just doesn't apply.

**`conflict` status from `mok-enroll-status`**
A key with the same CN is enrolled but with a different fingerprint. This
happens after key rotation where the old key wasn't deleted. See Key rotation
section above.

**SBAT mismatch blocks boot**
SBAT (Secure Boot Advanced Targeting) mismatches are independent of MOK.
Track Fedora shim releases: `mokutil --sbat` shows current SBAT revocations.

## VM / OVMF testing

For CI or developer testing in QEMU/KVM:
```bash
# Copy OVMF vars template (preserves Secure Boot defaults)
cp /usr/share/edk2/ovmf/OVMF_VARS.fd /tmp/test-vars.fd

# Boot with Secure Boot enabled
qemu-system-x86_64 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/ovmf/OVMF_CODE.secboot.fd \
  -drive if=pflash,format=raw,file=/tmp/test-vars.fd \
  ...
```

In the VM, `mokutil --sb-state` should report `SecureBoot enabled`.
Use `mokutil --import` as normal — the test VM has its own MOK database.

## References

- [GRUB2 Secure Boot flow (Fedora)](https://fedoraproject.org/wiki/Shim)
- [mokutil man page](https://github.com/lcp/mokutil)
- [bootc UKI tracking issue](https://github.com/bootc-dev/bootc/issues/806)
- [systemd-cryptenroll PCR binding](https://www.freedesktop.org/software/systemd/man/latest/systemd-cryptenroll.html)
