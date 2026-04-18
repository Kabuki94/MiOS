---
description: Run the full CI lint pipeline locally (shellcheck + hadolint + yamllint + TOML validation + PSScriptAnalyzer)
---

Run every linter that `.github/workflows/pr-lint.yml` runs, in the
same order, with the same strictness. This reproduces the CI gate
locally so a push is high-confidence before it goes out.

### 1. shellcheck on every `*.sh`

```
find . -type f -name '*.sh' \
    -not -path './.git/*' \
    -not -path './tmp/*' \
    -print0 \
  | xargs -0 shellcheck -S warning
```

Treat **SC2038, SC2206, SC2013, SC2012, SC2155, SC2015, SC2059,
SC2162, SC2010, SC2054** as **fatal** (the action-shellcheck@2.0.0
runner does the same).

### 2. shellcheck on extensionless scripts

```
shellcheck -S warning \
  scripts/cloudws-motd \
  system_files/usr/libexec/cloudws/* \
  system_files/usr/bin/gamescope-session-steam \
  system_files/usr/local/bin/cloudws-ceph \
  system_files/etc/greenboot/check/wanted.d/*.sh
```

Add any file the tree grows under `system_files/usr/libexec/cloudws/`
automatically.

### 3. hadolint on the Containerfile

```
hadolint Containerfile
```

No warnings. Add `# hadolint ignore=DLxxxx` only with a one-line
justification directly above.

### 4. yamllint on workflows + configs

```
yamllint .github/workflows/ renovate.json image-versions.yml
```

### 5. TOML validation

```
find . -type f -name '*.toml' -not -path './.git/*' -print0 \
  | xargs -0 -n1 taplo check
```

Plus the special `kargs.d/*.toml` check (from `/fix-kargs`):

```
for f in kargs.d/*.toml; do
    python3 -c "
import tomllib, pathlib, sys
d = tomllib.loads(pathlib.Path('$f').read_text())
assert 'kargs' in d, 'missing top-level kargs'
assert isinstance(d['kargs'], list), 'kargs must be a list'
assert all(isinstance(x, str) for x in d['kargs']), 'kargs entries must all be strings'
assert 'delete' not in d, 'delete key is not valid in bootc kargs.d'
print(f'{'$f'}: ok')
"
done
```

### 6. PSScriptAnalyzer on every `*.ps1`

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Settings PSGallery -Severity Error,Warning
```

Treat **PSAvoidUsingInvokeExpression** and **PSAvoidUsingEmptyCatchBlock**
as fatal (CLAUDE.md §3.8).

### 7. `bootc container lint` (if available)

If `bootc` is on PATH and we're on a Linux host:

```
bootc container lint \
  --image ghcr.io/kabuki94/cloudws-bootc:latest \
  2>&1 | tee build/bootc-lint.log
```

Specifically scan the output for:
- `Parsing .../kargs.d/...` errors (rule §3.3)
- `composefs` verification failures (rule §9 — post-pivot
  verification)

### 8. Summary

Print per-tool results as:

```
shellcheck:        N files, X errors, Y warnings
hadolint:          N issues
yamllint:          N issues
taplo:             N TOML files, X invalid
kargs.d validator: N files, X invalid
PSScriptAnalyzer:  N scripts, X errors, Y warnings
bootc lint:        <pass/fail/skipped>
```

If anything failed, state clearly at the top: **DO NOT PUSH**.
Otherwise: **Safe to push.**
