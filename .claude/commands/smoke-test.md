---
description: Run the bcvk-wrapper + smoke-check pipeline against a built image. Uses explicit `wsl -e` so the shell stays embedded in the integrated terminal, not an external WSL popup.
argument-hint: [image-ref] [timeout-seconds]
---

Run the CloudWS-bootc ephemeral boot smoke test against `$1` (default
`ghcr.io/kabuki94/cloudws-bootc:latest`) with a boot timeout of `$2`
seconds (default 300).

This mirrors `.github/workflows/build-test.yml` so local runs match
CI.

**Hard rule:** never invoke bare `bash` on Windows — it routes through
`wsl.exe` and spawns external windows. Always use `wsl -e bash -c
'...'` or `wsl --exec /bin/bash -c '...'` which keep output in the
integrated terminal.

## Steps

1. **Locate the harness.**
   - `scripts/bcvk-wrapper.sh`
   - `scripts/smoke-check.sh`

2. **Prepare the image.**
   - Local image (`localhost/…` or bare `cloudws:…`) → skip pull.
   - Otherwise `podman pull $1`.

3. **Generate disk image via BIB** using `config/bib.toml` (or a
   specified `bib-configs/*.toml`). Output:
   `build/cloudws-smoke.qcow2`.

4. **Boot headless.** On Windows, inside WSL using the explicit form:

```powershell
wsl -e bash -c "./scripts/bcvk-wrapper.sh --image build/cloudws-smoke.qcow2 --timeout $2 --serial-log build/smoke-serial.log"
```

   On Linux (native):
```bash
./scripts/bcvk-wrapper.sh --image build/cloudws-smoke.qcow2 --timeout $2 --serial-log build/smoke-serial.log
```

5. **Analyze serial log** — same `wsl -e` pattern on Windows:

```powershell
wsl -e bash -c "./scripts/smoke-check.sh build/smoke-serial.log"
```

6. **Verify post-pivot root.**
   - Grep the log for `cloudws-verify-root.service: Deactivated
     successfully`.
   - If present, list the eight paths it checked; confirm all passed.

7. **Cleanup.**
   - Remove `build/cloudws-smoke.qcow2` unless `--keep` was requested.
   - Keep the serial log for post-mortem.

## Exit codes

- `0` — boot reached target, no errors.
- `1` — lint / prerequisite failure.
- `2` — boot timeout or kernel panic.
- `3` — post-boot verification failed.
- `4` — user-visible warning (e.g. NVIDIA modules loading in a VM
  without a GPU — §3.5 regressed).

## Notes

- Local reproduction of CI only. Signing / SBOM / artifact generation
  still run in the signed workflow.
- Whenever possible run this from a Linux host. On Windows, `wsl -e`
  is acceptable; bare `bash` is not.
