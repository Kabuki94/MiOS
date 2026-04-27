<!-- 🌐 MiOS Artifact | Proprietor: Kabu.ki | https://github.com/kabuki94/mios -->
# 🌐 MiOS — Cloud Native Operating System
```json:knowledge
{
  "summary": "> **Proprietor:** Kabu.ki",
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
> **Proprietor:** Kabu.ki
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to Kabu.ki
---
---
description: Scaffold a new numbered automation/NN-*.sh provisioning script following MiOS conventions
argument-hint: <number> <short-name-kebab-case>
---

Create `automation/$1-$2.sh` following the MiOS provisioning
script conventions. `$1` is a two-digit number that slots into the
ordering (01=repos, 02=kernel, 05=external-repos, 08=overlays,
10=gnome, 11=hardware, 12=virt, 13=ceph-k3s, 20=services, 30=locale,
31=user, 32=hostname, 33=firewall, 34=gpu-detect, 35=gpu-passthrough,
36=tools, 37=selinux, 38=vm-gating, 39=desktop-polish, 40=composefs,
41=akmods-copy, 42=cosign-policy, 43=uupd, 44=podman-machine-compat,
45=nvidia-cdi-refresh, 46=greenboot, 47=hardening).

If `$1` collides with an existing script, stop and report the conflict.

### Scaffold template

```bash
#!/usr/bin/env bash
# automation/$1-$2.sh — <one-line description>
# Runs inside the Containerfile build stage as root.
#
# Contract:
#   - Idempotent: safe to re-run; existing state must not break.
#   - Reads /ctx/PACKAGES.md via automation/lib/packages.sh when packages are needed.
#   - Writes overlays under overlay/ (copied into place by 08-system-files-overlay.sh).
#   - Emits progress via printf (no plaintext secrets, ever).

set -euo pipefail
# shellcheck source=lib/packages.sh
source "$(dirname "$0")/lib/packages.sh"

STEP="[$1-$2]"
step() { printf '%s %s\n' "$STEP" "$*" >&2; }

# -- 1. Prerequisite check --------------------------------------------------
step "starting"

# -- 2. Main work -----------------------------------------------------------
# TODO: implement.

# -- 3. Post-conditions -----------------------------------------------------
step "done"
```

### Rules (enforced by `pr-lint.yml`)

- Shebang is `#!/usr/bin/env bash` — always.
- `set -euo pipefail` is required.
- **Never** use `((VAR++))` — use `VAR=$((VAR + 1))`. Violating this
  is rule §3.2 in `SYSTEM.md`.
- Quote every variable expansion.
- `find -exec` over `find | xargs`.
- `compgen -G` over `ls | grep`.
- `for u in $(< file)` over `for u in $(cat file)`.
- `read -r` / `read -ra`, never bare `read`.
- Separate declaration and assignment for command substitutions
  (`local KVER; KVER=$(uname -r)`).
- If you install packages, they must come from `specs/PACKAGES.md` via
  the `packages::` helper in `lib/packages.sh` — never inline the
  package list.
- Overlays go in `overlay/`, not this script.
- systemd units go in `systemd/`, not this script.

### After creating the file

1. Make it executable: `chmod +x automation/$1-$2.sh`.
2. Run `shellcheck -S warning automation/$1-$2.sh`.
3. Add a reference to it in the Containerfile build sequence if the
   numbering doesn't auto-pick it up.
4. Remind the user that the script will only land when the next push
   script ships it.

---
### 📚 Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osautomation/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [Kabuki94/mios](https://github.com/Kabuki94/mios)
- **Sole Proprietor:** Kabu.ki
---
<!-- ⚖️ MiOS Proprietary Artifact | Copyright (c) 2026 Kabu.ki -->
