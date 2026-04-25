#!/usr/bin/bash
# 45-nvidia-cdi-refresh.sh - wire up NVIDIA CDI auto-refresh services.
# Package installs live in PACKAGES.md (packages-gpu-nvidia section).
#
# Key invariants:
#   - nvidia-container-toolkit ≥ 1.18 for nvidia-cdi-refresh.service/path.
#   - Avoid NCT v2.1.0: "unresolvable CDI devices" regression. Use v2.1.0 or 1.18+.
#   - Remove oci-nvidia-hook.json: dual injection with CDI causes conflicts.
#   - CDI canonical path: /var/run/cdi/nvidia.yaml (runtime) or /etc/cdi/nvidia.yaml (persistent).
#   - NVIDIA kmods blacklisted by default; 34-gpu-detect.sh removes blacklist on bare metal.
set -euo pipefail

log() { printf '[45-nvidia-cdi] %s\n' "$*"; }

# Remove legacy OCI hook — conflicts with CDI when both are present.
OCI_HOOK=/usr/share/containers/oci/hooks.d/oci-nvidia-hook.json
if [[ -f "$OCI_HOOK" ]]; then
    log "removing legacy OCI nvidia hook (conflicts with CDI)"
    rm -f "$OCI_HOOK"
fi

# Pin nvidia-container-toolkit version in the CDI env file.
# The systemd service reads this at boot via EnvironmentFile.
install -d -m 0755 /etc/nvidia-container-toolkit
cat >/etc/nvidia-container-toolkit/cdi-refresh.env <<'EOF'
# Managed by 45-nvidia-cdi-refresh.sh
# CDI output path — runtime location preferred by bootc (ephemeral, cleared on boot).
CDI_OUTPUT_PATH=/var/run/cdi/nvidia.yaml
# Debug logging — set to 1 for troubleshooting.
NVIDIA_CTK_DEBUG=0
EOF
chmod 0644 /etc/nvidia-container-toolkit/cdi-refresh.env

# Toolkit-shipped units (require nvidia-container-toolkit >= 1.18).
log "enabling nvidia-cdi-refresh units"
systemctl enable nvidia-cdi-refresh.path    2>/dev/null || log "note: nvidia-cdi-refresh.path not available (NCT < 1.18)"
systemctl enable nvidia-cdi-refresh.service 2>/dev/null || log "note: nvidia-cdi-refresh.service not available (NCT < 1.18)"
systemctl enable nvidia-persistenced.service 2>/dev/null || true

# MiOS CDI detect shim — handles bare metal vs VM vs no-GPU context.
# Unit is in system_files/usr/lib/systemd/system/mios-nvidia-cdi.service.
if systemctl cat mios-nvidia-cdi.service >/dev/null 2>&1; then
    log "enabling mios-nvidia-cdi.service"
    systemctl enable mios-nvidia-cdi.service
else
    log "WARN: mios-nvidia-cdi.service missing from system_files — skipping"
fi

# Ensure CDI persistent dir exists; tmpfiles.d/mios-gpu.conf creates the runtime dir.
install -d -m 0755 /etc/cdi

log "CDI refresh pipeline configured"
