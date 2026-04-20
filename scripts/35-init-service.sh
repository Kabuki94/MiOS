#!/bin/bash
# CloudWS v2.0 — 35-init-service: Every-boot initialization
# Handles: home directories, groups, firewall, CrowdSec, Flatpak theme,
# Hyper-V enhanced session, Avahi/mDNS, podman garbage collection.
set -euo pipefail

echo "[35-init-service] Installing CloudWS init service..."

# Prevent DHCP IP conflicts in cloned VM environments by forcing
# NetworkManager to use the MAC address for DHCP client IDs instead
# of the potentially duplicated /etc/machine-id.
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/10-cloudws-dhcp-mac.conf <<'EONM'
[connection]
ipv4.dhcp-client-id=mac
ipv6.dhcp-duid=ll
EONM

cat > /usr/lib/systemd/system/cloudws-init.service <<'EOSVC'
[Unit]
Description=CloudWS System Init
Wants=network-online.target
After=network-online.target cloud-final.service ignition-firstboot-complete.service
[Service]
Type=oneshot
ExecStart=/usr/libexec/cloudws-init
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOSVC

cat > /usr/libexec/cloudws-init <<'EOINIT'
#!/bin/bash
set -euo pipefail

# ── Unique hostname (stable across reboots, unique across VM clones) ──
MAC=$(cat /sys/class/net/e*/address /sys/class/net/w*/address 2>/dev/null | head -1 || echo "")
MACH_ID=$(cat /etc/machine-id 2>/dev/null || echo "")

if [ -n "$MACH_ID" ]; then
    TAG=$(echo "${MACH_ID}${MAC}" | md5sum | head -c 5)
    CURRENT=$(hostname -s 2>/dev/null || echo "")
    if [ "$CURRENT" = "cloudws" ] || [ "$CURRENT" = "localhost" ] || [ "$CURRENT" = "linux" ]; then
        hostnamectl set-hostname "cloudws-${TAG}" 2>/dev/null || true
        echo "[cloudws-init] Hostname set to cloudws-${TAG}"
    fi
fi

# Ensure /var/opt exists (for /opt → /var/opt symlink)
mkdir -p /var/opt

# Ensure home directories exist (bootc /var/home)
for u in $(awk -F: '$3 >= 1000 && $3 < 65000 {print $1}' /etc/passwd); do
    home=$(getent passwd "$u" | cut -d: -f6)
    if [ ! -d "$home" ]; then
        mkdir -p "$home"
        cp -a /etc/skel/. "$home/" 2>/dev/null || true
        uid=$(id -u "$u"); gid=$(id -g "$u")
        chown -R "${uid}:${gid}" "$home"
    fi
done

# Ensure groups are correct
for u in $(awk -F: '$3 >= 1000 && $3 < 65000 {print $1}' /etc/passwd); do
    for g in wheel libvirt kvm video render input dialout; do
        usermod -aG "$g" "$u" 2>/dev/null || true
    done
done

# Firewall init (only if firewalld active)
/usr/libexec/cloudws-firewall-init 2>/dev/null || true

# CrowdSec registration (only on bare metal)
VIRT=$(systemd-detect-virt 2>/dev/null || echo "none")
if [ "$VIRT" = "none" ] && command -v cscli &>/dev/null; then
    cscli hub update 2>/dev/null || true
    cscli collections install crowdsecurity/linux 2>/dev/null || true
fi

# PCP restart (ensures metrics collection)
systemctl restart pmproxy.service 2>/dev/null || true

# Flatpak dark theme
flatpak override --system --env=ADW_DEBUG_COLOR_SCHEME=prefer-dark 2>/dev/null || true

# Hyper-V Enhanced Session auto-enable
if [[ "$VIRT" == "microsoft" ]]; then
    /usr/libexec/cloudws-hyperv-enhanced 2>/dev/null || true
fi

# Fix SELinux labels that may not survive ostree deploy
restorecon -v /boot/bootupd-state.json 2>/dev/null || true
restorecon -R /usr/share/accountsservice 2>/dev/null || true

# bootc status
bootc status 2>/dev/null || true

echo "[cloudws-init] CloudWS v2.0 initialized"
EOINIT
chmod +x /usr/libexec/cloudws-init
systemctl enable cloudws-init.service 2>/dev/null || true

# ═══ PODMAN GARBAGE COLLECTION TIMER ═══
echo "[35-init-service] Installing Podman garbage collection timer..."

cat > /usr/lib/systemd/system/cloudws-podman-gc.service <<'EOGC'
[Unit]
Description=CloudWS Podman Garbage Collection
Wants=podman.socket
[Service]
Type=oneshot
ExecStart=/usr/libexec/cloudws-podman-gc
EOGC

cat > /usr/lib/systemd/system/cloudws-podman-gc.timer <<'EOGCTIMER'
[Unit]
Description=Weekly Podman cleanup
[Timer]
OnCalendar=weekly
Persistent=true
RandomizedDelaySec=3600
[Install]
WantedBy=timers.target
EOGCTIMER

cat > /usr/libexec/cloudws-podman-gc <<'EOGCSCRIPT'
#!/bin/bash
set -euo pipefail
echo "[cloudws-podman-gc] Starting garbage collection..."
# Remove stopped containers
podman container prune -f 2>/dev/null || true
# Remove images older than 7 days that aren't in use
podman image prune -a -f --filter 'until=168h' 2>/dev/null || true
# Remove unused volumes
podman volume prune -f 2>/dev/null || true
# Remove unused networks
podman network prune -f 2>/dev/null || true
# Clear build cache
podman builder prune -a -f 2>/dev/null || true
# Report
echo "[cloudws-podman-gc] Disk usage after cleanup:"
podman system df 2>/dev/null || true
EOGCSCRIPT
chmod +x /usr/libexec/cloudws-podman-gc
systemctl enable cloudws-podman-gc.timer 2>/dev/null || true

# ═══ AVAHI / mDNS — Network discovery ═══
echo "[35-init-service] Configuring Avahi/mDNS for .local discovery..."
mkdir -p /etc/avahi/services

# Advertise Cockpit
cat > /etc/avahi/services/cockpit.service <<'EOAVAHI'
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">CloudWS Management (%h)</name>
  <service>
    <type>_https._tcp</type>
    <port>9090</port>
    <txt-record>path=/</txt-record>
  </service>
</service-group>
EOAVAHI

# Advertise RDP
cat > /etc/avahi/services/rdp.service <<'EOAVAHI'
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">CloudWS Remote Desktop (%h)</name>
  <service>
    <type>_rdp._tcp</type>
    <port>3389</port>
  </service>
</service-group>
EOAVAHI

echo "[35-init-service] Init service + GC timer + Avahi installed."
