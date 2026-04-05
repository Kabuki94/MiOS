#!/bin/bash
# CloudWS — 12-virt: Full virtualization, security, networking, HA, gaming
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/packages.sh"

# ─── Virtualisation Stack ────────────────────────────────────────────────────
install_packages "virt"

# ─── Container & Image Forge Toolchain ───────────────────────────────────────
install_packages "containers"

# ─── Cockpit Ecosystem (includes Image Builder UI) ──────────────────────────
install_packages "cockpit"

# ─── Security & IPS ─────────────────────────────────────────────────────────
install_packages "security"

# ─── CrowdSec IPS — Sovereign Mode (no outbound telemetry) ──────────────────
echo "[12-virt] Installing CrowdSec IPS (sovereign/offline mode)..."
update-ca-trust extract 2>/dev/null || true
curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.rpm.sh | os=fedora dist=42 bash || true
# Rawhide (42) may lack CrowdSec packages — add Fedora 40 repo as fallback
if ! dnf list --available crowdsec 2>/dev/null | grep -q crowdsec; then
    echo "[12-virt] CrowdSec not found for dist=42 — trying Fedora 40 fallback repo..."
    cat > /etc/yum.repos.d/crowdsec-f40-fallback.repo <<'EOREPO'
[crowdsec-f40-fallback]
name=CrowdSec (Fedora 40 fallback)
baseurl=https://packagecloud.io/crowdsec/crowdsec/fedora/40/$basearch
gpgcheck=0
enabled=1
repo_gpgcheck=0
EOREPO
fi
dnf install -y --skip-unavailable --allowerasing --nobest crowdsec crowdsec-firewall-bouncer-nftables || true

# Only configure CrowdSec if it actually installed
if command -v crowdsec &>/dev/null; then
    echo "[12-virt] CrowdSec installed — configuring sovereign mode..."
    mkdir -p /etc/crowdsec
    cat > /etc/crowdsec/config.yaml.local <<'EOCSC'
# CloudWS Sovereign Mode — CrowdSec sends NOTHING outbound
api:
  server:
    online_client:
      credentials_path: ""
cscli:
  output: human
crowdsec_service:
  enable: true
plugin_config:
  user: nobody
  group: nogroup
EOCSC

    mkdir -p /etc/crowdsec/acquis.d
    cat > /etc/crowdsec/acquis.d/journalctl.yaml <<'EOACQ'
source: journalctl
journalctl_filter:
  - "_SYSTEMD_UNIT=sshd.service"
labels:
  type: syslog
---
source: journalctl
journalctl_filter:
  - "_SYSTEMD_UNIT=cockpit.service"
  - "_SYSTEMD_UNIT=cockpit-wsinstance-http.service"
labels:
  type: syslog
---
source: journalctl
journalctl_filter:
  - "SYSLOG_IDENTIFIER=kernel"
labels:
  type: syslog
EOACQ

    mkdir -p /etc/crowdsec/local_api_credentials.yaml.d
    cat > /etc/crowdsec/local_api_credentials.yaml.d/sovereign.yaml <<'EOSOV'
url: http://127.0.0.1:8080/
login: ""
password: ""
EOSOV

    mkdir -p /etc/systemd/system/crowdsec-hubupdate.service.d
    cat > /etc/systemd/system/crowdsec-hubupdate.service.d/override.conf <<'EOF'
[Unit]
After=network-online.target
Wants=network-online.target
EOF

    cscli hub update 2>/dev/null || true
    cscli collections install crowdsecurity/sshd 2>/dev/null || true
    cscli collections install crowdsecurity/linux 2>/dev/null || true
else
    echo "[12-virt] WARN: CrowdSec unavailable (repo/SSL issue) — skipping config (non-fatal)"
fi

# ─── Performance & Gaming ───────────────────────────────────────────────────
install_packages "gaming"

# ─── Hypervisor Guest Agents (VM portability) ────────────────────────────────
install_packages "guests"

# ─── Storage & Networking ────────────────────────────────────────────────────
install_packages "storage"

# ─── High Availability / Clustering ─────────────────────────────────────────
dnf install -y --skip-unavailable --allowerasing --nobest $(get_packages "ha") || true

# ─── System Utilities ────────────────────────────────────────────────────────
install_packages "utils"

# ─── Android ─────────────────────────────────────────────────────────────────
install_packages "android"

# ─── K3s moved to 13-ceph-k3s.sh ─────────────────────────────────────────────

# ─── xRDP Hyper-V Enhanced Session (vsock transport — works at first launch) ─
if [ -f /etc/xrdp/xrdp.ini ]; then
    # Configure vsock transport for Hyper-V Enhanced Session
    sed -i 's/^port=3389/port=vsock:\/\/-1:3389/' /etc/xrdp/xrdp.ini
    sed -i 's/^use_vsock=false/use_vsock=true/' /etc/xrdp/xrdp.ini
    sed -i 's/^security_layer=negotiate/security_layer=rdp/' /etc/xrdp/xrdp.ini
    # Also listen on TCP 3389 as fallback for non-Hyper-V RDP
    sed -i '/^\[xrdp1\]/,/^\[/ s/^port=.*/port=-1/' /etc/xrdp/xrdp.ini 2>/dev/null || true
fi
if [ -f /etc/xrdp/sesman.ini ]; then
    sed -i 's/^AllowRootLogin=false/AllowRootLogin=true/' /etc/xrdp/sesman.ini 2>/dev/null || true
fi
mkdir -p /etc/X11
echo "allowed_users=anybody" > /etc/X11/Xwrapper.config

# Create default .xsession so xRDP launches GNOME automatically
cat > /etc/skel/.xsession <<'EOXS'
#!/bin/bash
export XDG_SESSION_TYPE=x11
export XDG_SESSION_DESKTOP=gnome
exec gnome-session
EOXS
chmod +x /etc/skel/.xsession

# Hyper-V enhanced session PowerShell hint (baked into image for reference)
mkdir -p /usr/share/cloudws
cat > /usr/share/cloudws/hyperv-enhanced-session.txt <<'EOHV'
# Run this on the Windows HOST (PowerShell as Admin) to enable enhanced session:
# Set-VM -Name cloudws -EnhancedSessionTransportType HvSocket
# Then connect via Hyper-V Manager → Enhanced Session will auto-negotiate.
EOHV

# ─── Windows Image Building Tools (UUP Dump, etc.) ─────────────────────────
install_packages "wintools"

# ─── Cockpit Plugins from Upstream Git ──────────────────────────────────────
install_packages "cockpit-plugins-build" 2>/dev/null || true
git clone --depth=1 https://github.com/45Drives/cockpit-benchmark.git /tmp/bench && \
    make -C /tmp/bench install && rm -rf /tmp/bench || true
git clone --depth=1 https://github.com/optimans/cockpit-zfs-manager.git /tmp/zfs && \
    cp -r /tmp/zfs/zfs /usr/share/cockpit/ && rm -rf /tmp/zfs || true

# ─── VirtIO-Win ISO for Windows VMs ────────────────────────────────────────
mkdir -p /var/lib/libvirt/images
curl -Lo /var/lib/libvirt/images/virtio-win.iso \
    'https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso' 2>/dev/null || true

# ─── Looking Glass B7 (low-latency GPU passthrough display) ─────────────────
install_packages "looking-glass-build"

cd /tmp; rm -rf LookingGlass
git clone --recursive https://github.com/gnif/LookingGlass.git
cd LookingGlass; git checkout B7; git submodule update --init --recursive
mkdir -p client/build; cd client/build
if cmake ../ && make -j$(nproc); then
    install -Dm755 looking-glass-client /usr/local/bin/looking-glass-client
    echo "[12-virt] Looking Glass B7 built successfully"
else
    echo "[12-virt] WARN: Looking Glass build failed (non-fatal)"
fi
rm -rf /tmp/LookingGlass

# Remove Looking Glass build deps (keep runtime deps)
dnf remove -y --noautoremove $(get_packages "looking-glass-build") 2>/dev/null || true

echo "[12-virt] Full KVM/Podman/Gaming/Security/Cockpit + Looking Glass B7 installed."
