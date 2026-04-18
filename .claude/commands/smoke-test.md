---
description: Run the bcvk-wrapper + smoke-check pipeline against a built image
argument-hint: [image-ref] [timeout-seconds]
---

Run the CloudWS-bootc ephemeral boot smoke test against `$1` (default
`ghcr.io/kabuki94/cloudws-bootc:latest`) with a boot timeout of `$2`
seconds (default 300).

This mirrors what `.github/workflows/build-test.yml` does for CI, so
local runs should produce the same pass/fail verdict.

### Steps

1. **Locate the harness.**
   - `scripts/bcvk-wrapper.sh` — headless QEMU boot harness.
   - `scripts/smoke-check.sh` — serial-log analyzer.
   - If either is missing, stop and tell the user which one.

2. **Prepare the image.**
   - If `$1` looks like a local image (`localhost/…` or bare
     `cloudws:…`), skip pull.
   - Otherwise `podman pull $1`.

3. **Generate a disk image via BIB.**
   - Use `config/bib.toml` (primary) or a specified `bib-configs/*.toml`.
   - Output target: `build/cloudws-smoke.qcow2` under the repo root
     (create `build/` if absent; `.gitignore` it in the push script
     if not already).

4. **Boot it headless.**
   - `scripts/bcvk-wrapper.sh --image build/cloudws-smoke.qcow2
     --timeout $2 --serial-log build/smoke-serial.log`
   - The wrapper should exit non-zero on kernel panic, systemd
     emergency mode, or timeout.

5. **Analyze the serial log.**
   - `scripts/smoke-check.sh build/smoke-serial.log`
   - Report every WARN and ERROR it surfaces.

6. **Verify the post-pivot root.**
   - If the boot reached multi-user, `cloudws-verify-root.service`
     should have run. Grep the log for
     `cloudws-verify-root.service: Deactivated successfully`.
   - If present, list the eight paths it checked and confirm all
     passed.

7. **Clean up.**
   - Remove `build/cloudws-smoke.qcow2` unless `--keep` was
     requested.
   - Keep the serial log for post-mortem.

### Exit codes

- `0` — boot reached GDM (or multi-user for headless variants), no
  errors in the serial log.
- `1` — linting / prerequisite failure.
- `2` — boot timeout or panic.
- `3` — post-boot verification failed (composefs paths, units in
  failed state, etc).
- `4` — user-visible warning (e.g. NVIDIA modules loaded in a VM
  without a GPU — a sign §3.5 regressed).

### Notes

- This is a **local reproduction** of CI. It does not replace CI —
  full signing, SBOM, and artifact generation only happen in the
  signed workflow.
- The test should run inside the CloudWS image itself when possible
  (`CLAUDE.md` §1.2, principle 2: the image is its own builder).
