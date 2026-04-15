<#
.SYNOPSIS
    CloudWS-bootc v2.2 — Ecosystem Audit Integration Push
.DESCRIPTION
    ROOT CAUSE: kargs.d TOML files use invalid [kargs] table headers.
    bootc kargs.d only supports bare "kargs = [...]" format.
    Also: dracut hyperv_fb→hyperv_drm, missing /root, SecureBlue hardening,
    composefs prep, Flatpak first-boot, NVIDIA CDI, WSL2 fix, SSH hardening.
.NOTES
    Run from any directory. Clones fresh → patches → pushes to main.
#>

$ErrorActionPreference = 'Stop'

$RepoUrl  = "https://github.com/Kabuki94/CloudWS-bootc.git"
$Branch   = "main"
$WorkDir  = Join-Path $env:TEMP "cloudws-v22-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$RepoDir  = Join-Path $WorkDir "CloudWS-bootc"

# ── Helper: write UTF-8 no-BOM with LF endings ───────────────────────────────
function Write-Utf8Lf {
    param([string]$Path, [string]$Content)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, ($Content -replace "`r`n", "`n"), [System.Text.UTF8Encoding]::new($false))
}

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  CloudWS-bootc v2.2 — Ecosystem Audit Integration          ║" -ForegroundColor Cyan
Write-Host "║  FIX: kargs TOML parse + dracut hyperv_fb + 14 new files   ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# ══════════════════════════════════════════════════════════════════════════════
# 1. CLONE
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "`n[1/6] Cloning..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
git clone --depth 1 --branch $Branch $RepoUrl $RepoDir 2>&1
if ($LASTEXITCODE -ne 0) { throw "Clone failed" }
Push-Location $RepoDir

# ══════════════════════════════════════════════════════════════════════════════
# 2. DELETE MALFORMED TOML FILES (ROOT CAUSE)
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "`n[2/6] Deleting malformed kargs.d files..." -ForegroundColor Yellow

@(
    "system_files/usr/lib/bootc/kargs.d/01-cloudws-vm-boot.toml",
    "system_files/usr/lib/bootc/kargs.d/10-cloudws-console.toml"
) | ForEach-Object {
    if (Test-Path $_) {
        git rm -f $_ 2>&1 | Out-Null
        Write-Host "  ✗ Removed: $_" -ForegroundColor Red
    } else {
        Write-Host "  - Already gone: $_" -ForegroundColor DarkGray
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# 3. WRITE ALL NEW/REPLACEMENT FILES
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "`n[3/6] Writing 15 files..." -ForegroundColor Green

# ── 3a. kargs.d: correct bare TOML format ────────────────────────────────────
Write-Utf8Lf "system_files/usr/lib/bootc/kargs.d/00-cloudws.toml" @'
# CloudWS v2.2 — Core kernel boot arguments
# bootc kargs.d (v1.13+). Format: bare kargs = [...] ONLY.
# NO [kargs] table headers. NO delete/append keys.

kargs = [
    "iommu=pt",
    "amd_iommu=on",
    "nvidia-drm.modeset=1",
    "nvidia-drm.fbdev=1",
    "rd.driver.blacklist=nouveau",
    "modprobe.blacklist=nouveau",
    "systemd.show-status=true",
    "console=tty0",
    "console=ttyS0,115200n8"
]
match-architectures = ["x86_64"]
'@
Write-Host "  ✓ kargs.d/00-cloudws.toml (IOMMU+NVIDIA+console)" -ForegroundColor Green

Write-Utf8Lf "system_files/usr/lib/bootc/kargs.d/01-cloudws-hardening.toml" @'
# CloudWS v2.2 — SecureBlue-adapted kernel hardening

kargs = [
    "slab_nomerge",
    "init_on_alloc=1",
    "init_on_free=1",
    "page_alloc.shuffle=1",
    "randomize_kstack_offset=on",
    "pti=on",
    "vsyscall=none",
    "lockdown=confidentiality",
    "spectre_v2=on",
    "spec_store_bypass_disable=on",
    "l1tf=full,force",
    "gather_data_sampling=force"
]
match-architectures = ["x86_64"]
'@
Write-Host "  ✓ kargs.d/01-cloudws-hardening.toml (SecureBlue)" -ForegroundColor Green

# ── 3b. composefs preparation ─────────────────────────────────────────────────
Write-Utf8Lf "system_files/usr/lib/ostree/prepare-root.conf" @'
# CloudWS v2.2 — composefs-native backend (bootc v1.14+)
[composefs]
enabled = yes

[sysroot]
readonly = true
'@
Write-Host "  ✓ ostree/prepare-root.conf (composefs enabled)" -ForegroundColor Green

# ── 3c. dracut conf.d: fix hyperv_fb + multi-surface boot ────────────────────
Write-Utf8Lf "system_files/usr/lib/dracut/dracut.conf.d/10-cloudws-generic.conf" @'
# CloudWS v2.2 — Generic initramfs for all deployment surfaces
hostonly="no"
hostonly_cmdline="no"
early_microcode="yes"
compress="zstd"
'@
Write-Host "  ✓ dracut.conf.d/10-cloudws-generic.conf" -ForegroundColor Green

Write-Utf8Lf "system_files/usr/lib/dracut/dracut.conf.d/50-cloudws-hyperv.conf" @'
# CloudWS v2.2 — Hyper-V drivers (hyperv_drm replaces hyperv_fb in 6.x+)
add_drivers+=" hv_vmbus hv_netvsc hv_storvsc hv_utils hv_balloon hv_sock "
add_drivers+=" hid-hyperv hyperv_keyboard hyperv_drm "
'@
Write-Host "  ✓ dracut.conf.d/50-cloudws-hyperv.conf (hyperv_drm fix)" -ForegroundColor Green

Write-Utf8Lf "system_files/usr/lib/dracut/dracut.conf.d/51-cloudws-virtio.conf" @'
# CloudWS v2.2 — VirtIO + NVMe + AHCI for QEMU/KVM and bare metal
add_drivers+=" virtio_blk virtio_net virtio_scsi virtio_pci virtio_balloon virtio_console virtio_rng "
add_drivers+=" nvme nvme_core ahci sd_mod sr_mod "
'@
Write-Host "  ✓ dracut.conf.d/51-cloudws-virtio.conf" -ForegroundColor Green

Write-Utf8Lf "system_files/usr/lib/dracut/dracut.conf.d/52-cloudws-nvidia-exclude.conf" @'
# CloudWS v2.2 — Exclude NVIDIA from initramfs (loads post-boot via modprobe)
omit_drivers+=" nvidia nvidia_drm nvidia_modeset nvidia_peermem nvidia_uvm "
'@
Write-Host "  ✓ dracut.conf.d/52-cloudws-nvidia-exclude.conf" -ForegroundColor Green

# ── 3d. Security: sysctl + SSH hardening ──────────────────────────────────────
Write-Utf8Lf "system_files/usr/lib/sysctl.d/99-cloudws-hardening.conf" @'
# CloudWS v2.2 — Kernel sysctl hardening (SecureBlue + CIS)
# Admin overrides: /etc/sysctl.d/ (higher priority)

# Network
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_timestamps = 0

# Kernel
kernel.sysrq = 4
kernel.core_uses_pid = 1
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.perf_event_paranoid = 3
kernel.yama.ptrace_scope = 2
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2

# Filesystem
fs.suid_dumpable = 0
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2

# VM / Performance (Ryzen 9 9950X3D)
vm.swappiness = 10
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.max_map_count = 2147483642
'@
Write-Host "  ✓ sysctl.d/99-cloudws-hardening.conf" -ForegroundColor Green

Write-Utf8Lf "system_files/etc/ssh/sshd_config.d/50-cloudws-hardened.conf" @'
# CloudWS v2.2 — SSH hardening (key-only, no root)
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
MaxAuthTries 3
MaxSessions 5
ClientAliveInterval 300
ClientAliveCountMax 2
PermitEmptyPasswords no
'@
Write-Host "  ✓ sshd_config.d/50-cloudws-hardened.conf" -ForegroundColor Green

# ── 3e. Cockpit ───────────────────────────────────────────────────────────────
Write-Utf8Lf "system_files/etc/cockpit/cockpit.conf" @'
# CloudWS v2.2 — Cockpit (requires >=330 for composefs compat)
[WebService]
LoginTo = false
AllowUnencrypted = false
UrlRoot = /
MaxStartups = 10

[Session]
IdleTimeout = 15
'@
Write-Host "  ✓ etc/cockpit/cockpit.conf" -ForegroundColor Green

# ── 3f. Flatpak first-boot (Bazzite pattern) ─────────────────────────────────
Write-Utf8Lf "system_files/usr/libexec/cloudws-flatpak-install" @'
#!/bin/bash
# CloudWS v2.2 — First-boot Flatpak installer (idempotent with sentinel)
set -euo pipefail

VER=1
VER_FILE="/etc/cloudws/.flatpak-version"
SCRIPT_HASH=$(sha256sum "$0" | cut -d' ' -f1)
VER_RUN="${VER}-${SCRIPT_HASH}"
FLATPAK_LIST="/usr/share/cloudws/flatpak-list"
LOG="/var/log/cloudws-flatpak-install.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

if [ -f "$VER_FILE" ] && [ "$(cat "$VER_FILE")" = "$VER_RUN" ]; then
    log "Already at version ${VER} — skipping"; exit 0
fi
mkdir -p /etc/cloudws
log "CloudWS Flatpak installer v${VER} starting"

# Remotes
flatpak remote-add --system --if-not-exists flathub \
    https://flathub.org/repo/flathub.flatpakrepo 2>&1 | tee -a "$LOG" || true
flatpak remote-modify --system --disable fedora 2>&1 | tee -a "$LOG" || true
flatpak remote-modify --system --disable fedora-testing 2>&1 | tee -a "$LOG" || true

# Install from list
if [ -f "$FLATPAK_LIST" ]; then
    log "Installing from ${FLATPAK_LIST}..."
    while IFS= read -r app || [ -n "$app" ]; do
        [[ -z "$app" || "$app" == \#* ]] && continue
        log "  → ${app}"
        flatpak install -y --noninteractive --system flathub "$app" 2>&1 | tee -a "$LOG" || \
            log "  WARNING: ${app} failed"
    done < "$FLATPAK_LIST"
fi

# GTK theming passthrough
flatpak override --system --filesystem=xdg-config/gtk-3.0:ro 2>&1 | tee -a "$LOG" || true
flatpak override --system --filesystem=xdg-config/gtk-4.0:ro 2>&1 | tee -a "$LOG" || true
flatpak override --system --env=GTK_THEME=adw-gtk3-dark 2>&1 | tee -a "$LOG" || true

echo "$VER_RUN" > "$VER_FILE"
log "Complete"
'@
Write-Host "  ✓ usr/libexec/cloudws-flatpak-install" -ForegroundColor Green

Write-Utf8Lf "system_files/usr/lib/systemd/system/cloudws-flatpak-install.service" @'
[Unit]
Description=CloudWS Flatpak First-Boot Installer
After=network-online.target
Wants=network-online.target
Before=display-manager.service

[Service]
Type=oneshot
ExecStart=/usr/libexec/cloudws-flatpak-install
TimeoutStartSec=600
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
'@
Write-Host "  ✓ cloudws-flatpak-install.service" -ForegroundColor Green

Write-Utf8Lf "system_files/usr/share/cloudws/flatpak-list" @'
# CloudWS v2.2 — Flatpak apps (first-boot install)
org.mozilla.firefox
org.libreoffice.LibreOffice
org.gnome.Ptyxis
io.missioncenter.MissionCenter
com.mattjakeman.ExtensionManager
org.gnome.Loupe
org.gnome.TextEditor
org.gnome.Calculator
org.gnome.clocks
'@
Write-Host "  ✓ usr/share/cloudws/flatpak-list" -ForegroundColor Green

# ── 3g. NVIDIA CDI for rootless Podman GPU ────────────────────────────────────
Write-Utf8Lf "system_files/usr/lib/systemd/system/cloudws-nvidia-cdi.service" @'
[Unit]
Description=Generate NVIDIA CDI spec for rootless Podman GPU
After=nvidia-persistenced.service
ConditionPathExists=/usr/bin/nvidia-ctk
ConditionVirtualization=!vm

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
ExecStartPost=/usr/bin/nvidia-ctk cdi list

[Install]
WantedBy=multi-user.target
'@
Write-Host "  ✓ cloudws-nvidia-cdi.service" -ForegroundColor Green

# ── 3h. WSL2 dbus-broker fix ─────────────────────────────────────────────────
Write-Utf8Lf "system_files/usr/lib/systemd/system/dbus-broker.service.d/10-cloudws-no-audit.conf" @'
# CloudWS v2.2 — dbus-broker: strip --audit for WSL2 compat
[Service]
ExecStart=
ExecStart=/usr/bin/dbus-broker-launch --scope system
'@
Write-Host "  ✓ dbus-broker.service.d/10-cloudws-no-audit.conf" -ForegroundColor Green

# ══════════════════════════════════════════════════════════════════════════════
# 4. PATCH CONTAINERFILE
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "`n[4/6] Patching Containerfile..." -ForegroundColor Cyan

$cf = Get-Content "Containerfile" -Raw -ErrorAction Stop

# 4a. Fix dracut: add mkdir /root + --reproducible --add ostree
$patchApplied = $false

# Pattern 1: exact match from v2.1.x Containerfile
if ($cf -match 'DRACUT_NO_XATTR=1 dracut --force --no-hostonly --kver') {
    $cf = $cf -replace 'DRACUT_NO_XATTR=1 dracut --force --no-hostonly --kver',
        'mkdir -p /root && DRACUT_NO_XATTR=1 /usr/bin/dracut --no-hostonly --reproducible --add ostree --kver'
    $patchApplied = $true
    Write-Host "  ✓ Dracut: +mkdir /root +--reproducible +--add ostree" -ForegroundColor Green
}
# Pattern 2: variant with --force but different ordering
if (-not $patchApplied -and $cf -match 'dracut --force.*--kver.*initramfs') {
    $cf = $cf -replace '(if \[ -n "\$KVER" \]; then)',
        '$1' + "`n" + '        mkdir -p /root;'
    if ($cf -notmatch '--reproducible') {
        $cf = $cf -replace 'dracut --force', 'dracut --force --reproducible --add ostree'
    }
    Write-Host "  ✓ Dracut: patched (variant syntax)" -ForegroundColor Green
}

# 4b. Enable cloudws-nvidia-cdi.service in overlay step
if ($cf -notmatch 'cloudws-nvidia-cdi') {
    $cf = $cf -replace '(systemctl enable cloudws-verify-root\.service[^\n]*)',
        ('$1' + " &&`n" + '    systemctl enable cloudws-nvidia-cdi.service 2>/dev/null && echo "  ✓ cloudws-nvidia-cdi" || echo "  ⚠ cloudws-nvidia-cdi"')
    Write-Host "  ✓ Enable cloudws-nvidia-cdi.service" -ForegroundColor Green
}

# 4c. Mask Fedora flatpak remote service
if ($cf -notmatch 'flatpak-add-fedora-repos') {
    $cf = $cf -replace '(echo "── Service enablement complete ──")',
        ('systemctl mask flatpak-add-fedora-repos.service 2>/dev/null || true && echo "  ✓ masked flatpak-add-fedora-repos" &&' + "`n" + '    $1')
    Write-Host "  ✓ Mask flatpak-add-fedora-repos.service" -ForegroundColor Green
}

# 4d. Bump version label
$cf = $cf -replace 'org\.opencontainers\.image\.version="[^"]*"',
    'org.opencontainers.image.version="2.2.0"'
Write-Host "  ✓ Version → 2.2.0" -ForegroundColor Green

Write-Utf8Lf "Containerfile" $cf

# Bump VERSION file
Write-Utf8Lf "VERSION" "2.2.0"
Write-Host "  ✓ VERSION → 2.2.0" -ForegroundColor Green

# ══════════════════════════════════════════════════════════════════════════════
# 5. COMMIT
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "`n[5/6] Committing..." -ForegroundColor Cyan

git add -A 2>&1
git status --short

$msg = @"
v2.2.0: Fix bootc lint + ecosystem audit integration

BUILD FIX (root cause):
- Delete 10-cloudws-console.toml + 01-cloudws-vm-boot.toml
  ([kargs] table headers invalid — bootc requires bare kargs=[...])
- Replace 00-cloudws.toml: correct format, consolidate all args

DRACUT FIX:
- mkdir -p /root before dracut (fixes 'installing /root' error)
- --reproducible --add ostree (uCore proven pattern)
- dracut.conf.d: hyperv_drm (not hyperv_fb), VirtIO, NVMe, NVIDIA exclude
- hostonly=no + zstd compression

SECURITY (SecureBlue-adapted):
- kargs.d/01-cloudws-hardening.toml: slab_nomerge, init_on_alloc/free,
  lockdown=confidentiality, spectre_v2, pti, vsyscall=none, l1tf
- sysctl.d/99-cloudws-hardening.conf: network+kernel+fs hardening
- sshd_config.d/50-cloudws-hardened.conf: key-only, no root, no fwd

COMPOSEFS:
- prepare-root.conf: [composefs] enabled=yes (v1.14+ transition)

FLATPAK (Bazzite pattern):
- cloudws-flatpak-install: idempotent first-boot with sentinel
- flatpak-list: curated Flathub app set
- Mask flatpak-add-fedora-repos.service

NVIDIA:
- cloudws-nvidia-cdi.service: CDI spec for rootless Podman GPU

WSL2:
- dbus-broker drop-in: strip --audit (WSL2 lacks audit subsystem)

COCKPIT:
- cockpit.conf: socket-activated, no unencrypted, idle timeout 15m
"@

git commit -m $msg 2>&1

# ══════════════════════════════════════════════════════════════════════════════
# 6. PUSH
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "`n[6/6] Pushing to $Branch..." -ForegroundColor Cyan
git push origin $Branch 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║  PUSH COMPLETE — v2.2.0                                    ║" -ForegroundColor Green
    Write-Host "║  bootc container lint should now pass.                     ║" -ForegroundColor Green
    Write-Host "║  Rebuild: .\cloud-ws.ps1                                  ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
} else {
    Write-Host "  ✗ Push failed" -ForegroundColor Red
}

Pop-Location
Write-Host "Work dir: $WorkDir`n"
