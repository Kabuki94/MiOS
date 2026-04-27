<!-- 🌐 MiOS Artifact | Proprietor: MiOS Project | https://github.com/mios-project/mios -->
# 🌐 MiOS
```json:knowledge
{
  "summary": "> **Proprietor:** MiOS Project",
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
> **Proprietor:** MiOS Project
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to MiOS Project
---
---
description: Rewrite a kargs.d/*.toml file to the canonical flat-array form that bootc accepts. PowerShell / native-python only — no bare bash invocations.
argument-hint: <path-to-kargs.d-file>
---

Read `$1` and rewrite it to the canonical bootc `kargs.d` form
defined in `INDEX.md` §3.3.

**Never invoke bare `bash` on Windows during this operation** — it
spawns external WSL popups. Use PowerShell or direct `python` calls
only; both stay in the integrated terminal.

The **only** acceptable format is:

```toml
# Optional leading comment describing the purpose of this drop-in.
kargs = [
    "key=value",
    "flag-with-no-value",
    "another=value",
]
```

### Things to remove

- `[kargs]` section headers — bootc rejects these.
- `delete = [...]`, `delete_kargs = [...]`, `remove = [...]` — no
  such key exists in bootc. Deletion happens via merging (last
  drop-in wins).
- Inline tables, arrays-of-tables, nested structures.
- Non-string values.
- Trailing commas that `taplo lint` objects to.

### Things to preserve

- Existing comments (use TOML `#` style).
- The exact karg strings already present (don't invent, don't "fix"
  values you don't understand).
- The filename.

### After rewriting

1. Write the result back to `$1`.

2. Validate with `taplo check` (no bash needed):
   ```powershell
   taplo check $1
   ```

3. Validate the schema semantically with Python — runs natively on
   Windows without WSL:
   ```powershell
   python -c "import tomllib,pathlib,sys; p='$1'; d=tomllib.loads(pathlib.Path(p).read_text()); assert 'kargs' in d and isinstance(d['kargs'],list) and all(isinstance(x,str) for x in d['kargs']) and 'delete' not in d, 'invalid kargs.d'; print(p + ': ok')"
   ```

4. If a bootc-capable host is available, run `bootc container lint`
   via explicit `wsl -e` (not bare bash):
   ```powershell
   wsl -e bash -c "bootc container lint --image <ref>"
   ```

5. Print a diff of the old vs new file using PowerShell:
   ```powershell
   git diff --no-index -- <backup-of-original> $1
   ```

6. If anything changed, remind the user to include `$1` in the next
   push script.

### Example — broken (Copilot-authored) input

```toml
[kargs]
kargs = [ "quiet", "rhgb" ]
delete = [ "systemd.show-status=true" ]
```

### Example — canonical output

```toml
# VM-boot kargs: suppress splash and enable verbose boot status.
kargs = [
    "systemd.show-status=true",
]
```

The deletion of `quiet` / `rhgb` happens via merging (another drop-in
omits them) — bootc has no direct `delete` mechanism.

---
### 📚 Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osautomation/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [mios-project/mios](https://github.com/mios-project/mios)
- **Sole Proprietor:** MiOS Project
---
<!-- ⚖️ MiOS Proprietary Artifact | Copyright (c) 2026 MiOS Project -->
