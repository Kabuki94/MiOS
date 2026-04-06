#!/bin/bash
# CloudWS v1.3 — 20-services: Enable systemd services + environment gating
# Services that are only useful on bare metal get ConditionVirtualization=no
# drop-ins so they silently skip in VMs. WSL2-incompatible services get
# ConditionPathExists drop-ins. Eliminates 60-90s boot delays + crash-loops.
set -euo pipefail

# ─── Core services (run everywhere) ──────────────────────────────────────────
systemctl enable libvirtd.service virtqemud.socket virtnetworkd.socket virtstoraged.socket
systemctl enable cockpit.socket sshd.service
systemctl enable tuned.service
# NOTE: Only pmproxy is installed — pmcd and pmlogger are NOT in PACKAGES.md.
# Enabling nonexistent units causes build failures on Rawhide.
systemctl enable pmproxy.service 2>/dev/null || true
if systemctl list-unit-files firewalld.service &>/dev/null; then
    systemctl enable firewalld.service
else
    echo "[20-services] NOTICE: firewalld.service not found — installing..."
    dnf -y install firewalld --skip-unavailable 2>/dev/null || true
    systemctl enable firewalld.service 2>/dev/null || echo "[20-services] WARNING: firewalld still not available"
fi
systemctl enable chronyd.service 2>/dev/null || true

# ─── Optional services (fail silently if package wasn't installed) ────────────
systemctl enable fapolicyd.service usbguard.service 2>/dev/null || true
systemctl enable qemu-guest-agent.service hypervvssd.service hypervkvpd.service 2>/dev/null || true
systemctl enable tailscaled.service 2>/dev/null || true
systemctl enable waydroid-container.service cloud-init.service 2>/dev/null || true
systemctl enable podman.socket podman-auto-update.timer podman-restart.service 2>/dev/null || true
systemctl enable xrdp.service xrdp-sesman.service 2>/dev/null || true
systemctl enable auditd.service 2>/dev/null || true

# ─── K3s + Ceph services ─────────────────────────────────────────────────────
systemctl enable k3s.service 2>/dev/null || true
systemctl enable var-home.mount 2>/dev/null || true
systemctl enable var-lib-containers.mount 2>/dev/null || true
systemctl enable ceph-bootstrap.service 2>/dev/null || true

# ─── Database services (disabled by default — user starts when needed) ────────
# These are installed but NOT auto-started. Use cloudws-db to manage.
systemctl disable mariadb.service 2>/dev/null || true
systemctl disable postgresql.service 2>/dev/null || true
systemctl disable redis.service 2>/dev/null || true
echo "[20-services] Database services installed but disabled (use: cloudws-db start)"

# ─── VM HA services (sanlock) ────────────────────────────────────────────────
systemctl enable sanlock.service 2>/dev/null || true
systemctl enable virtlockd.socket 2>/dev/null || true
echo "[20-services] VM HA lock services enabled"

# ─── First-boot timezone geolocation service ─────────────────────────────────
cat > /usr/lib/systemd/system/cloudws-timezone-init.service <<'EOTZSVC'
[Unit]
Description=CloudWS First-Boot Timezone Detection (geolocation)
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/var/lib/cloudws/.timezone-configured
[Service]
Type=oneshot
ExecStart=/usr/libexec/cloudws-timezone-init
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOTZSVC

cat > /usr/libexec/cloudws-timezone-init <<'EOTZINIT'
#!/bin/bash
# CloudWS: Fetch timezone from IP geolocation on first boot, then disable location services.
# Useful for cluster deployments — each node auto-configures its timezone.
set -euo pipefail

MARKER="/var/lib/cloudws/.timezone-configured"
mkdir -p /var/lib/cloudws

# Try multiple geo-IP services (all free, no API key)
TZ=""
for url in \
    "http://ip-api.com/json/?fields=timezone" \
    "https://ipapi.co/timezone" \
    "https://worldtimeapi.org/api/ip" \
; do
    RESP=$(curl -sf --max-time 10 "$url" 2>/dev/null || true)
    if [ -n "$RESP" ]; then
        # ip-api.com returns JSON with "timezone" key
        TZ=$(echo "$RESP" | grep -oP '"timezone"\s*:\s*"\K[^"]+' 2>/dev/null || true)
        # ipapi.co returns plain text timezone
        if [ -z "$TZ" ] && echo "$RESP" | grep -qP '^[A-Z][a-z]+/[A-Z]'; then
            TZ="$RESP"
        fi
        # worldtimeapi.org returns JSON
        if [ -z "$TZ" ]; then
            TZ=$(echo "$RESP" | grep -oP '"timezone"\s*:\s*"\K[^"]+' 2>/dev/null || true)
        fi
        [ -n "$TZ" ] && break
    fi
done

# Fallback to GeoIP database if all HTTP calls fail
if [ -z "$TZ" ] && command -v geoiplookup &>/dev/null; then
    # Get country from external IP, map to common timezone
    COUNTRY=$(curl -sf --max-time 5 https://ipinfo.io/country 2>/dev/null || true)
    case "$COUNTRY" in
        US) TZ="America/New_York" ;;
        CA) TZ="America/Toronto" ;;
        GB) TZ="Europe/London" ;;
        DE) TZ="Europe/Berlin" ;;
        JP) TZ="Asia/Tokyo" ;;
        AU) TZ="Australia/Sydney" ;;
        *) TZ="UTC" ;;
    esac
fi

# Final fallback
TZ="${TZ:-UTC}"

echo "[cloudws-timezone] Setting timezone to: $TZ"
timedatectl set-timezone "$TZ" 2>/dev/null || ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime

# Disable GNOME location services (not needed after timezone is set)
mkdir -p /etc/dconf/db/local.d/locks
cat > /etc/dconf/db/local.d/02-cloudws-location <<'EODCONF'
[org/gnome/system/location]
enabled=false
EODCONF

cat > /etc/dconf/db/local.d/locks/cloudws-location <<'EOLOCK'
/org/gnome/system/location/enabled
EOLOCK

dconf update 2>/dev/null || true

# Mark as done — service won't run again
touch "$MARKER"
echo "[cloudws-timezone] Timezone configured to $TZ — location services disabled"
EOTZINIT
chmod +x /usr/libexec/cloudws-timezone-init
systemctl enable cloudws-timezone-init.service
echo "[20-services] First-boot timezone geolocation service enabled"

# ─── FIX: Mount unit file permissions ────────────────────────────────────────
# systemd warns on every boot if these are executable or world-writable.
# Container builds sometimes leave bad perms from COPY operations.
for unit_file in \
    /etc/systemd/system/var-home.mount \
    /etc/systemd/system/var-lib-containers.mount \
    /etc/systemd/system/ceph-bootstrap.service \
    /etc/systemd/system/cockpit.socket.d/listen.conf \
; do
    [ -f "$unit_file" ] && chmod 644 "$unit_file"
done
echo "[20-services] Fixed systemd unit file permissions"

# ─── Bare-metal-only services ────────────────────────────────────────────────
BARE_METAL_SERVICES=(
    nfs-server
    smb
    nmb
    pacemaker
    corosync
    pcsd
    crowdsec
    crowdsec-firewall-bouncer
    multipathd
    osbuild-composer
    osbuild-worker@1
)

for svc in "${BARE_METAL_SERVICES[@]}"; do
    systemctl enable "${svc}.service" 2>/dev/null || true
    DROPIN_DIR="/usr/lib/systemd/system/${svc}.service.d"
    mkdir -p "$DROPIN_DIR"
    cat > "${DROPIN_DIR}/10-bare-metal-only.conf" <<'DROPIN'
[Unit]
# CloudWS: Skip this service in VMs/containers — bare metal only
ConditionVirtualization=no
DROPIN
done
echo "[20-services] Bare-metal-only drop-ins created for: ${BARE_METAL_SERVICES[*]}"

# ─── WSL2-specific service gating ────────────────────────────────────────────
# These services crash-loop or are useless in WSL2.
WSL_SKIP_SERVICES=(
    gdm
    firewalld
    waydroid-container
    nvidia-powerd
    crowdsec
    crowdsec-firewall-bouncer
    dev-binderfs.mount
    ceph-bootstrap
    auditd
    audit-rules
    bootloader-update
    usbguard
    mariadb
    postgresql
    redis
    sanlock
    pacemaker
    corosync
    pcsd
)

for svc in "${WSL_SKIP_SERVICES[@]}"; do
    unit="${svc}"
    [[ "$unit" != *.* ]] && unit="${unit}.service"
    if [ -f "/usr/lib/systemd/system/${unit}" ] || [ -f "/etc/systemd/system/${unit}" ]; then
        mkdir -p "/usr/lib/systemd/system/${unit}.d"
        cat > "/usr/lib/systemd/system/${unit}.d/10-skip-wsl.conf" <<'DROPIN'
[Unit]
# CloudWS: Skip in WSL2 — service incompatible with WSL2 environment
ConditionPathExists=!/proc/sys/fs/binfmt_misc/WSLInterop
DROPIN
    fi
done
echo "[20-services] WSL2 skip drop-ins installed for: ${WSL_SKIP_SERVICES[*]}"

# ─── nvidia-powerd: skip in ALL VMs (no physical NVIDIA GPU) ─────────────────
if [ -f /usr/lib/systemd/system/nvidia-powerd.service ]; then
    mkdir -p /usr/lib/systemd/system/nvidia-powerd.service.d
    cat > /usr/lib/systemd/system/nvidia-powerd.service.d/10-bare-metal-only.conf <<'DROPIN'
[Unit]
# CloudWS: NVIDIA power daemon only works with physical GPU
ConditionVirtualization=no
DROPIN
fi

# ─── serial-getty@ttyS0: mask everywhere ─────────────────────────────────────
# Crash-loops in Hyper-V (no serial port). Bare metal can unmask if needed.
systemctl mask serial-getty@ttyS0.service 2>/dev/null || true

tuned-adm profile throughput-performance 2>/dev/null || true

echo "[20-services] All services enabled and gated. v1.3 complete."
