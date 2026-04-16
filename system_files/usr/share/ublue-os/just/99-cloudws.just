# CloudWS ujust recipes

# Show the currently active role
cloudws-role-status:
    @cat /var/lib/cloudws/role.active 2>/dev/null || echo "role not yet applied"
    @echo "default target: $(systemctl get-default)"

# Switch role: ujust cloudws-set-role desktop | k3s-master | k3s-worker | ha-node | hybrid | headless
cloudws-set-role ROLE:
    #!/usr/bin/bash
    set -e
    PROFILE=$(awk -F= '/^PROFILE=/{print $2}' /etc/cloudws/role.conf 2>/dev/null || echo workstation)
    FEATURES=$(awk -F= '/^FEATURES=/{print $2}' /etc/cloudws/role.conf 2>/dev/null)
    printf 'ROLE=%s\nPROFILE=%s\nFEATURES=%s\n' '{{ROLE}}' "$PROFILE" "$FEATURES" | \
      sudo install -Dm0644 /dev/stdin /etc/cloudws/role.conf
    sudo systemctl restart cloudws-role.service
    echo "role set to {{ROLE}}; reboot to fully apply"

# Enroll the ublue-os MOK cert (one-time, for NVIDIA Secure Boot)
cloudws-enroll-mok:
    sudo mokutil --import /etc/pki/akmods/certs/akmods-ublue.der
    @echo "Set password when prompted, then reboot. MOK Manager will appear."
    @echo "Password to use during MOK enrollment: universalblue"

# Verify signed image before switching
cloudws-verify IMAGE="ghcr.io/kabuki94/cloudws-bootc:latest":
    cosign verify \
      --certificate-identity-regexp 'https://github.com/Kabuki94/CloudWS-bootc/.*' \
      --certificate-oidc-issuer     https://token.actions.githubusercontent.com \
      {{IMAGE}}

# Rebase to a signed digest (not :latest)
cloudws-rebase IMAGE:
    sudo bootc switch --enforce-container-sigpolicy {{IMAGE}}

# Pause auto-updates (for gaming / critical work)
cloudws-pause-updates:
    sudo systemctl stop uupd.timer
    sudo systemctl disable uupd.timer
    @echo "updates paused; resume with: ujust cloudws-resume-updates"

cloudws-resume-updates:
    sudo systemctl enable --now uupd.timer

# Show composefs / verity status
cloudws-verity-status:
    @grep -E 'composefs|enabled' /usr/lib/ostree/prepare-root.conf 2>/dev/null || echo "prepare-root.conf not present"
    @mount | grep -E 'composefs|overlay' || true
# -------- Looking Glass (BAKED IN since v2.2.2) ----------------------------

# Enable kvmfr autoload at boot (required for Looking Glass)
cloudws-looking-glass-enable:
    sudo systemctl enable --now cloudws-kvmfr-load.service
    @echo "kvmfr enabled. Reboot or run: sudo modprobe kvmfr"
    @echo "Then run: looking-glass-client"

cloudws-looking-glass-disable:
    sudo systemctl disable --now cloudws-kvmfr-load.service
    sudo modprobe -r kvmfr 2>/dev/null || true

# Show Looking Glass status
cloudws-looking-glass-status:
    @echo "== kvmfr module =="
    @lsmod | grep kvmfr || echo "(not loaded)"
    @echo "== /dev/kvmfr0 =="
    @ls -la /dev/kvmfr0 2>/dev/null || echo "(device absent)"
    @echo "== client binary =="
    @which looking-glass-client && looking-glass-client --version 2>&1 | head -3