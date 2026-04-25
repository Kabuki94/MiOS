#!/usr/bin/env bash
# ============================================================================
# scripts/lib/common.sh
# ----------------------------------------------------------------------------
# Shared helpers for CloudWS-bootc build scripts.
# Safe to source multiple times (idempotent).
# ============================================================================

# --- Logging ----------------------------------------------------------------
log() { printf '==> %s\n' "$*"; }
warn(){ printf 'WARN: %s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# --- dnf flags --------------------------------------------------------------
# Select dnf binary (prefer dnf5 if available)
if command -v dnf5 &>/dev/null; then
    export DNF_BIN="dnf5"
else
    export DNF_BIN="dnf"
fi

# Defense-in-depth: /etc/dnf/dnf.conf already carries install_weak_deps=False,
# but passing it on every invocation guarantees behaviour even if a script or
# transaction overrides the global default. Array form so elements are one-
# argv-each under `set -u`, and future flags can be added in one place.
if [[ -z "${DNF_SETOPT+x}" || "$(declare -p DNF_SETOPT 2>/dev/null)" != "declare -a"* ]]; then
    declare -ga DNF_SETOPT=(--setopt=install_weak_deps=False --allowerasing --best)
fi
# String variant for legacy/debug visibility only. Do NOT use in commands.
export DNF_SETOPT_STR="${DNF_SETOPT[*]}"
