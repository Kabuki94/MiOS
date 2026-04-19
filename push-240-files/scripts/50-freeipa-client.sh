#!/usr/bin/bash
# 50-freeipa-client.sh — layer FreeIPA/SSSD client stack into the bootc image.
#
# Opt-in at runtime: cloudws-ipa-enroll.service runs only when
# /etc/cloudws/ipa.conf is present (ConditionPathExists) and the enrollment
# has not already completed (/var/lib/cloudws/ipa-enrolled marker missing).
#
# Key upstream notes (as of April 2026):
#   bz 2332433: /var/lib/ipa-client/sysrestore/ missing → pre-create via tmpfiles.d.
#   bz 2320133: SSSD file capabilities stripped by rpm-ostree < bootc 1.1.2-2.fc41.
#               We assert getcap post-install and fail the build if caps are absent.
#   bz 2417703: sssd_be crashes under bootc+IPA → workaround selinux_provider = none.
set -euo pipefail

# shellcheck source=/dev/null
source /usr/libexec/cloudws/lib/common.sh 2>/dev/null || true
: "${DNF:=dnf}"

log() { printf '[50-freeipa] %s\n' "$*"; }

log "installing FreeIPA client packages (excluding kernel*)"
"${DNF}" -y install \
    --exclude='kernel*' \
    freeipa-client \
    sssd \
    sssd-ipa \
    authselect \
    oddjob \
    oddjob-mkhomedir \
    certmonger \
    krb5-workstation

# ── SSSD file capability regression check (bz 2320133) ──────────────────────
log "verifying SSSD file capabilities"
declare -a SSSD_CAP_BINS=(
    /usr/libexec/sssd/krb5_child
    /usr/libexec/sssd/ldap_child
    /usr/libexec/sssd/selinux_child
    /usr/lib/sssd/sssd_pam
)
CAP_FAIL=0
for bin in "${SSSD_CAP_BINS[@]}"; do
    if [[ ! -f "$bin" ]]; then
        log "WARN: $bin not present (may be packaged differently on this Fedora release)"
        continue
    fi
    caps=$(getcap "$bin" 2>/dev/null || true)
    if [[ -z "$caps" ]]; then
        log "ERROR: $bin is missing file capabilities (bz 2320133 regression)"
        log "       This build requires bootc >= 1.1.2-2.fc41"
        CAP_FAIL=$((CAP_FAIL + 1))
    else
        log "OK: $bin → $caps"
    fi
done
if (( CAP_FAIL > 0 )); then
    log "FATAL: ${CAP_FAIL} SSSD binary(ies) lost file capabilities."
    log "       Upgrade the base image or pin a bootc version that includes the fix."
    exit 1
fi

# ── Disable services at build time (enabled at enrollment) ───────────────────
# Services start only after successful ipa-client-install via cloudws-ipa-enroll.
log "disabling IPA-related services at build time (enabled post-enrollment)"
for svc in sssd sssd.socket certmonger oddjobd; do
    systemctl disable "$svc" 2>/dev/null || true
done

# Enable the opt-in enrollment oneshot.
log "enabling cloudws-ipa-enroll.service (gated by ConditionPathExists)"
systemctl enable cloudws-ipa-enroll.service

log "FreeIPA client layer complete"
