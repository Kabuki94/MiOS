# GEMINI.md — CloudWS-bootc

> This file is read automatically by the **Gemini CLI** when invoked
> anywhere inside this repository. It is the per-repo instruction file
> for Gemini and takes precedence over general assistant behaviour.

---

## Primary source of truth

**All substantive project rules live in [`CLAUDE.md`](./CLAUDE.md).**

Gemini, before doing anything in this repo, **read `CLAUDE.md` in
full** — in particular:

- §1 — Project identity (Fedora bootc, two variants, published image)
- §2 — Repo layout
- §3 — Hard build rules (the non-negotiable ones)
- §4 — How the maintainer expects deliverables
- §7 — Roadmap boundaries
- §8 — What not to do

Do not duplicate those rules here. Both files drifting is worse than
either being out of date on its own.

---

## Gemini-specific notes

- The sole developer, **Kabu** (`Kabuki94`), works primarily from
  Windows with VSCodium. Prefer PowerShell-ready deliverables when
  the environment is Windows (`.ps1`) and shell-ready deliverables
  when the environment is Linux-native (e.g. the CI runner).
- Always produce **complete replacement files**, never patches.
  See `CLAUDE.md` §4.1.
- Before proposing a fix, **fetch the live repo content** — do not
  rely on your prior turn's understanding. The repo moves quickly.
- When Gemini is asked to "search for X in this repo", use the
  `@` file-reference syntax with real paths (e.g. `@scripts/02-kernel.sh`).
  Do not invent paths — the layout in `CLAUDE.md` §2 is authoritative.
- Gemini's web search is welcome when a fact is dated after Gemini's
  cutoff. For Fedora package/repo availability, the canonical sources
  are `koji.fedoraproject.org`, `packages.fedoraproject.org`, and
  `src.fedoraproject.org`.

---

## Build rule reminders (short list)

These are the rules most frequently broken by AI assistants on this
repo. The full rationale is in `CLAUDE.md` §3.

1. `kargs.d/*.toml` uses a flat top-level `kargs = [ ... ]` array.
   No `[kargs]` section header. No `delete` sub-key.
2. Do not upgrade `kernel` / `kernel-core` inside the container.
3. No `--squash-all` on `podman build`.
4. `((VAR++))` is forbidden under `set -euo pipefail`. Use
   `VAR=$((VAR + 1))`.
5. `GTK_THEME=Adwaita:dark` breaks libadwaita. Use
   `ADW_DEBUG_COLOR_SCHEME=prefer-dark`.
6. `/etc/skel/.bashrc` must be written before `useradd -m`.
7. No `Invoke-Expression`, no empty `catch {}`, no plaintext tokens.
8. `docs/PACKAGES.md` is the single source of truth for packages.
9. Push scripts **clone the existing repo**; they never `git init`.
10. Complete replacement files only. Never diffs or partial edits.

---

## Commands and workflows

Same set as Claude Code. When Gemini is asked to "push v2.4.0", the
expected deliverable is:

1. `push-v2.4.0.ps1` at the export root,
2. A companion directory of files to be copied into the repo,
3. Atomic commit with a structured message.

Nothing is run without Kabu's explicit confirmation.

---

*See `CLAUDE.md` for everything else. When this file disagrees with
`CLAUDE.md`, `CLAUDE.md` wins.*
