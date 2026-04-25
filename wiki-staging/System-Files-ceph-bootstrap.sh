# ceph-bootstrap.sh
---

#!/bin/bash
# MiOS — Ceph Cluster Bootstrap (runs ONCE on first bare-metal boot)
set -euo pipefail

log() { echo "[ceph-bootstrap] $(date '+%H:%M:%S') $*"; }

if [ "$(id -u)" -ne 0 ]; then log "ERROR: Must run as root"; exit 1; fi
if ! command -v cephadm &>/dev/null; then log "ERROR: cephadm not found"; exit 1; fi
if ! command -v podman &>/dev/null; then log "ERROR: podman not found"; exit 1; fi

MON_IP=$(hostname -I | awk '{print $1}')
if [ -z "$MON_IP" ]; then log "ERROR: No IP detected"; exit 1; fi
log "Monitor IP: $MON_IP | Hostname: $(hostname)"

log "Bootstrapping Ceph cluster..."
cephadm bootstrap \
    --mon-ip "$MON_IP" \
    --single-host-defaults \
    --skip-monitoring-stack \
    --allow-fqdn-hostname \
    --skip-firewalld

log "Configuring for single-node workstation..."
cephadm shell -- ceph config set global osd_pool_default_size 1 2>/dev/null || true
cephadm shell -- ceph config set global osd_pool_default_min_size 1 2>/dev/null || true
cephadm shell -- ceph config set mon mon_allow_pool_size_one true 2>/dev/null || true

# Memory tuning — 1 GB per OSD, 20% autotune ratio
cephadm shell -- ceph config set osd osd_memory_target 1073741824 2>/dev/null || true
cephadm shell -- ceph config set mgr mgr/cephadm/autotune_memory_target_ratio 0.2 2>/dev/null || true
cephadm shell -- ceph config set mds mds_cache_memory_limit 1073741824 2>/dev/null || true

log "Auto-provisioning OSDs..."
cephadm shell -- ceph orch apply osd --all-available-devices 2>/dev/null || true

log "Waiting for OSD(s)..."
OSD_READY=0
for i in $(seq 1 30); do
    OSD_UP=$(cephadm shell -- ceph osd stat -f json 2>/dev/null | \
        python3 -c "import sys,json; print(json.load(sys.stdin).get('num_up_osds',0))" 2>/dev/null || echo 0)
    [ "$OSD_UP" -gt 0 ] && { log "OSD(s) online: $OSD_UP"; OSD_READY=1; break; }
    log "Waiting... ($i/30)"; sleep 10
done

if [ "$OSD_READY" -eq 0 ]; then
    log "WARNING: No OSDs found. Add a disk later:"
    log "  ceph orch daemon add osd $(hostname):/dev/sdX"
    exit 0
fi

for pool in $(cephadm shell -- ceph osd pool ls 2>/dev/null); do
    cephadm shell -- ceph osd pool set "$pool" size 1 --yes-i-really-mean-it 2>/dev/null || true
    cephadm shell -- ceph osd pool set "$pool" min_size 1 2>/dev/null || true
done

log "Creating CephFS filesystem..."
cephadm shell -- ceph fs volume create cephfs --placement="1 $(hostname)" 2>/dev/null || true
sleep 15

cephadm shell -- ceph osd pool set cephfs.cephfs.meta size 1 --yes-i-really-mean-it 2>/dev/null || true
cephadm shell -- ceph osd pool set cephfs.cephfs.data size 1 --yes-i-really-mean-it 2>/dev/null || true
cephadm shell -- ceph fs subvolumegroup create cephfs csi 2>/dev/null || true

log "Creating mount credentials..."
cephadm shell -- ceph fs authorize cephfs client.mios / rw 2>/dev/null || true
cephadm shell -- ceph auth get-key client.mios > /etc/ceph/mios.secret 2>/dev/null || true
chmod 600 /etc/ceph/mios.secret 2>/dev/null || true
cephadm shell -- ceph auth get client.mios -o /etc/ceph/ceph.client.mios.keyring 2>/dev/null || true

log "Creating CephFS directories..."
TMPMNT=$(mktemp -d)
if mount -t ceph "mios@.cephfs=/" "$TMPMNT" -o "secretfile=/etc/ceph/mios.secret" 2>/dev/null; then
    mkdir -p "$TMPMNT/home" "$TMPMNT/containers"
    umount "$TMPMNT"
fi
rmdir "$TMPMNT" 2>/dev/null || true

cephadm shell -- ceph health mute POOL_NO_REDUNDANCY 2>/dev/null || true

# Inject real FSID/IP into K3s ceph-csi manifest
CEPH_FSID=$(cephadm shell -- ceph fsid 2>/dev/null || echo "")
MANIFEST="/var/lib/rancher/k3s/server/manifests/ceph-csi-cephfs.yaml"
if [ -n "$CEPH_FSID" ] && [ -f "$MANIFEST" ]; then
    sed -i "s/CEPH_FSID_PLACEHOLDER/$CEPH_FSID/g" "$MANIFEST"
    sed -i "s/MON_IP_PLACEHOLDER/$MON_IP/g" "$MANIFEST"
fi

log "══════════════════════════════════════════════════════════════"
log "  Ceph Cluster Bootstrap Complete!"
log "  Dashboard:    https://$MON_IP:8443"
log "  CephFS mounts activate on next reboot, or run:"
log "    systemctl start var-home.mount var-lib-containers.mount"
log "  Add nodes: ceph orch host add <hostname> <ip> --labels=osd"
log "══════════════════════════════════════════════════════════════"
