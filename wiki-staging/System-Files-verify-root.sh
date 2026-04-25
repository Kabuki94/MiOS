# verify-root.sh
---

#!/usr/bin/bash
# verify-root.sh — MiOS post-pivot root filesystem verification.
#
# Three-tier strategy:
#   Tier A: existence check (~22 critical paths). Always runs. Failure → exit 1.
#   Tier B: fsverity measure check against /usr/lib/mios/verify-root.digests.
#           No-op silently if file not present or if path lacks fs-verity.
#           (Default Fedora bootc composefs is unsigned — Tier B is advisory.)
#   Tier C: policy.json SHA-256 check against /usr/lib/mios/policy.json.sha256.
#           The baseline digest lives under /usr (composefs-covered). Failure → exit 1.
#
# Wire into greenboot via:
#   /etc/greenboot/check/required.d/10-mios-composefs.sh
set -euo pipefail

MISSING=0
TIER_B_FAIL=0
TIER_C_FAIL=0

log_info()  { echo "$*" | systemd-cat -t mios-verify -p info; }
log_warn()  { echo "$*" | systemd-cat -t mios-verify -p warning; }
log_err()   { echo "$*" | systemd-cat -t mios-verify -p err; }
log_crit()  { echo "$*" | systemd-cat -t mios-verify -p crit; }

# ── Tier A: existence ─────────────────────────────────────────────────────────

TIER_A_PATHS=(
    # bootc / ostree
    /usr/bin/bootc
    /usr/lib/bootc/install
    /usr/lib/bootc/kargs.d
    # containers
    /usr/bin/podman
    /usr/bin/skopeo
    /usr/bin/crun
    /etc/containers/policy.json
    /etc/containers/registries.d
    # systemd critical
    /usr/lib/systemd/systemd
    /usr/lib/systemd/systemd-executor
    /usr/lib/systemd/system-generators
    /usr/lib/systemd/systemd-journald
    /usr/lib/systemd/systemd-logind
    /usr/lib/systemd/systemd-udevd
    # display
    /usr/sbin/gdm
    /usr/lib/systemd/system/gdm.service
    # cockpit
    /usr/lib/systemd/system/cockpit.socket
    # mios helpers
    /usr/libexec/mios
    # selinux
    /etc/selinux/config
    /usr/sbin/setfiles
    # os-release
    /usr/lib/os-release
)

for path in "${TIER_A_PATHS[@]}"; do
    if [[ ! -e "$path" ]]; then
        log_err "mios-verify TierA: MISSING $path"
        MISSING=$((MISSING + 1))
    fi
done

# kernel modules dir (dynamic kver)
KVER=$(uname -r)
if [[ ! -d "/usr/lib/modules/${KVER}" ]]; then
    log_err "mios-verify TierA: MISSING /usr/lib/modules/${KVER}"
        MISSING=$((MISSING + 1))
fi

if (( MISSING > 0 )); then
    log_crit "mios-verify TierA: ${MISSING} critical path(s) missing — image may be corrupt"
fi

# ── Tier B: fsverity measure ──────────────────────────────────────────────────

DIGESTS_FILE=/usr/lib/mios/verify-root.digests
if [[ -f "$DIGESTS_FILE" ]] && command -v fsverity >/dev/null 2>&1; then
    while IFS=' ' read -r expected_hash path; do
        [[ "$expected_hash" =~ ^# ]] && continue
        [[ -z "$path" ]] && continue
        if [[ ! -f "$path" ]]; then
            log_warn "mios-verify TierB: path not found: $path"
            TIER_B_FAIL=$((TIER_B_FAIL + 1))
            continue
        fi
        actual_hash=$(fsverity measure "$path" 2>/dev/null | awk '{print $1}') || {
            log_warn "mios-verify TierB: fsverity measure failed for $path (not verity-enabled? skipping)"
            continue
        }
        if [[ "$actual_hash" != "$expected_hash" ]]; then
            log_err "mios-verify TierB: DIGEST MISMATCH $path"
            log_err "  expected: $expected_hash"
            log_err "  actual:   $actual_hash"
            TIER_B_FAIL=$((TIER_B_FAIL + 1))
        fi
    done < "$DIGESTS_FILE"
    if (( TIER_B_FAIL > 0 )); then
        log_warn "mios-verify TierB: ${TIER_B_FAIL} digest mismatch(es) — review /usr/lib/mios/verify-root.digests"
    fi
else
    log_info "mios-verify TierB: skipped (no digests file or fsverity not available)"
fi

# ── Tier C: policy.json SHA-256 ───────────────────────────────────────────────

POLICY_FILE=/etc/containers/policy.json
POLICY_HASH_FILE=/usr/lib/mios/policy.json.sha256

if [[ -f "$POLICY_HASH_FILE" ]]; then
    expected_sha256=$(cat "$POLICY_HASH_FILE")
    if [[ -f "$POLICY_FILE" ]]; then
        actual_sha256=$(sha256sum "$POLICY_FILE" | awk '{print $1}')
        if [[ "$actual_sha256" != "$expected_sha256" ]]; then
            log_err "mios-verify TierC: policy.json SHA-256 MISMATCH"
            log_err "  expected: $expected_sha256"
            log_err "  actual:   $actual_sha256"
            log_err "  If you legitimately changed policy.json, run:"
            log_err "    sha256sum /etc/containers/policy.json > /usr/lib/mios/policy.json.sha256"
            log_err "  and rebuild+push the image."
            TIER_C_FAIL=$((TIER_C_FAIL + 1))
        fi
    else
        log_err "mios-verify TierC: policy.json missing at ${POLICY_FILE}"
        TIER_C_FAIL=$((TIER_C_FAIL + 1))
    fi
else
    log_info "mios-verify TierC: skipped (no policy.json.sha256 baseline)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

if (( MISSING > 0 || TIER_C_FAIL > 0 )); then
    log_crit "mios-verify: FAILED (TierA=${MISSING} TierB=${TIER_B_FAIL} TierC=${TIER_C_FAIL})"
    exit 1
fi

log_info "mios-verify: all checks passed (TierA=ok TierB=${TIER_B_FAIL}w TierC=ok)"
exit 0
