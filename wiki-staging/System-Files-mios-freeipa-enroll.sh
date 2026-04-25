# mios-freeipa-enroll.sh
---

#!/usr/bin/env bash
set -eou pipefail

ENROLL_FILE="/etc/mios/ipa-enroll.env"

# If already enrolled, exit cleanly
if [ -f /etc/ipa/default.conf ]; then
    exit 0
fi

# If no enrollment credentials exist, exit cleanly
if [ ! -f "$ENROLL_FILE" ]; then
    exit 0
fi

echo "==> FreeIPA enrollment credentials found. Joining domain..."

# Source the variables securely: IPA_DOMAIN, IPA_SERVER, IPA_PRINCIPAL, IPA_PASSWORD
source "$ENROLL_FILE"

ipa-client-install --unattended \
    --domain="${IPA_DOMAIN}" \
    --server="${IPA_SERVER}" \
    --principal="${IPA_PRINCIPAL}" \
    --password="${IPA_PASSWORD}" \
    --mkhomedir --force-join

rm -f "$ENROLL_FILE"
echo "==> FreeIPA domain join complete. Credentials shredded."
