#!/usr/bin/env bash
# 22-freeipa-client.sh — install FreeIPA/SSSD client + arm zero-touch enrollment.
#
# Runtime path: cloudws-freeipa-enroll.service runs only when
# /etc/cloudws/ipa-enroll.env is present and /etc/ipa/default.conf is absent.
#
# Upstream regression notes (April 2026):
#   bz 2320133 — SSSD file caps stripped by rpm-ostree < bootc 1.1.2-2.fc41.
#                Asserted post-install; build fails fast if caps are missing.
#   bz 2332433 — /var/lib/ipa-client/sysrestore/ missing on first boot.
#                Pre-created via tmpfiles.d.
set -euo pipefail

echo "==> Installing FreeIPA & SSSD for zero-touch enrollment..."

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

# Install client + SSSD tooling. Exclude kernel* (hard-rule §3.1).
dnf "${DNF_SETOPT[@]}" install -y --exclude='kernel*' freeipa-client sssd sssd-tools

# ── SSSD file capability regression check (bz 2320133) ─────────────────────
echo "==> Verifying SSSD file capabilities..."
SSSD_CAP_BINS=(
    /usr/libexec/sssd/krb5_child
    /usr/libexec/sssd/ldap_child
    /usr/libexec/sssd/selinux_child
    /usr/lib/sssd/sssd_pam
)
CAP_FAIL=0
for bin in "${SSSD_CAP_BINS[@]}"; do
    [[ -f "$bin" ]] || continue
    caps=$(getcap "$bin" 2>/dev/null || true)
    if [[ -z "$caps" ]]; then
        echo "ERROR: $bin missing file capabilities (bz 2320133 regression)"
        CAP_FAIL=$((CAP_FAIL + 1))
    fi
done
if (( CAP_FAIL > 0 )); then
    echo "FATAL: ${CAP_FAIL} SSSD binary(ies) lost file capabilities — base image too old."
    exit 1
fi

# ── Pre-create ipa-client sysrestore (bz 2332433) ──────────────────────────
mkdir -p /usr/lib/tmpfiles.d
cat > /usr/lib/tmpfiles.d/cloudws-ipa.conf <<'EOF'
d /var/lib/ipa-client/sysrestore 0700 root root -
EOF

# ── Non-blocking timeout drop-in ───────────────────────────────────────────
# Ensure a missing/unreachable FreeIPA server doesn't hang the boot process
# for 5+ minutes waiting on DNS or TCP timeouts.
mkdir -p /usr/lib/systemd/system/cloudws-freeipa-enroll.service.d
cat > /usr/lib/systemd/system/cloudws-freeipa-enroll.service.d/10-boot-timeout.conf <<'EOF'
[Service]
TimeoutStartSec=120
EOF

# Arm the zero-touch enrollment oneshot (gated by ConditionPathExists).
systemctl enable cloudws-freeipa-enroll.service
