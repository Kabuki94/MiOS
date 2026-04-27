<!-- 🌐 MiOS Artifact | Proprietor: MiOS-DEV | https://github.com/mios-project/mios -->
# 🌐 MiOS
```json:knowledge
{
  "summary": "> **Proprietor:** MiOS-DEV",
  "logic_type": "documentation",
  "tags": [
    "MiOS",
    "commands"
  ],
  "relations": {
    "depends_on": [
      ".env.mios"
    ],
    "impacts": []
  }
}
```
> **Proprietor:** MiOS-DEV
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to MiOS-DEV
---
---
description: Run the bcvk-wrapper + smoke-check pipeline against a built image. Uses explicit `wsl -e` so the shell stays embedded in the integrated terminal, not an external WSL popup.
argument-hint: [image-ref] [timeout-seconds]
---

Run the MiOS ephemeral boot smoke test against `$1` (default
`ghcr.io/kabuki94/mios:latest`) with a boot timeout of `$2`
seconds (default 300).

This mirrors `.github/workflows/build-test.yml` so local runs match
CI.

**Hard rule:** never invoke bare `bash` on Windows — it routes through
`wsl.exe` and spawns external windows. Always use `wsl -e bash -c
'...'` or `wsl --exec /bin/bash -c '...'` which keep output in the
integrated terminal.

## Steps

1. **Locate the harness.**
   - `automation/bcvk-wrapper.sh`
   - `automation/smoke-check.sh`

2. **Prepare the image.**
   - Local image (`localhost/…` or bare `mios:…`) → skip pull.
   - Otherwise `podman pull $1`.

3. **Generate disk image via BIB** using `config/bib.toml` (or a
   specified `bib-configs/*.toml`). Output:
   `automation/mios-smoke.qcow2`.

4. **Boot headless.** On Windows, inside WSL using the explicit form:

```powershell
wsl -e bash -c "./automation/bcvk-wrapper.sh --image automation/mios-smoke.qcow2 --timeout $2 --serial-log automation/smoke-serial.log"
```

   On Linux (native):
```bash
./automation/bcvk-wrapper.sh --image automation/mios-smoke.qcow2 --timeout $2 --serial-log automation/smoke-serial.log
```

5. **Analyze serial log** — same `wsl -e` pattern on Windows:

```powershell
wsl -e bash -c "./automation/smoke-check.sh automation/smoke-serial.log"
```

6. **Verify post-pivot root.**
   - Grep the log for `mios-verify-root.service: Deactivated
     successfully`.
   - If present, list the eight paths it checked; confirm all passed.

7. **Cleanup.**
   - Remove `automation/mios-smoke.qcow2` unless `--keep` was requested.
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

---
### 📚 Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osautomation/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [mios-project/mios](https://github.com/mios-project/mios)
- **Sole Proprietor:** MiOS-DEV
---
<!-- ⚖️ MiOS Proprietary Artifact | Copyright (c) 2026 MiOS-DEV -->
