---
description: Rewrite a kargs.d/*.toml file to the canonical flat-array form that bootc accepts
argument-hint: <path-to-kargs.d-file>
---

Read `$1` and rewrite it to the canonical bootc `kargs.d` form
defined in `CLAUDE.md` §3.3.

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
  such key exists in bootc. If the intent was to drop an entry, it
  must be expressed through merging (the last drop-in wins).
- Inline tables, arrays-of-tables, anything nested.
- Non-string values (no bare numbers, no booleans — bootc kargs are
  all strings).
- Trailing commas on single-entry arrays if they cause `taplo lint`
  to complain (most TOML parsers accept them, but be conservative).

### Things to preserve

- Existing comments, migrated to TOML `#` style.
- The exact karg strings already present (don't invent new kargs,
  don't "fix" values you don't understand).
- The filename — do not rename the file.

### After rewriting

1. Write the result back to `$1`.
2. Run `taplo check $1` if taplo is available, else `python3 -c
   "import tomllib, pathlib; tomllib.loads(pathlib.Path('$1').read_text())"`.
3. Run `bootc container lint` against a container that includes the
   file, if a bootc-capable container is available.
4. Print a diff of the old vs new file.
5. If anything changed, remind the user to include `$1` in the next
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

(The deletion of `quiet` / `rhgb` happens because this drop-in
replaces them, or via another drop-in that omits them. There is no
direct `delete` mechanism.)
