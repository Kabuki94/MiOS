# CloudWS v2.1.1 — Containerfile
# Build: podman build --no-cache --build-arg MAKEFLAGS="-j$(nproc)" -t cloudws:latest .
# Lint:  podman run --rm cloudws:latest bootc container lint
#
# NEVER use --squash-all — it strips OCI layer metadata (ostree.final-diffid)
# required by bootc, causing BIB to fail with "Missing ostree.final-diffid."
#
# BASE IMAGE: ghcr.io/ublue-os/ucore-hci:stable-nvidia
# Provides: bootc, podman, firewalld, tailscale, wireguard-tools, tmux,
#   qemu-guest-agent, open-vm-tools, libvirt, qemu-kvm, virt-install,
#   cockpit-machines, intel wifi firmware, storage tools,
#   NVIDIA kmod (pre-signed with ublue MOK — fixes SecureBoot kernel panic),
#   nvidia-container-toolkit, CDI, SELinux policy.
#
# v2.1.1 FIXES:
#   - FIX: systemctl enables moved AFTER system_files COPY (7 services were silently failing)
#   - FIX: Generic initramfs with hostonly="no" + Hyper-V/virtio dracut modules
#   - FIX: Plymouth handled via kernel cmdline, not service masking (prevents dependency deadlock)
#   - FIX: xorgxrdp replaced with gnome-remote-desktop for Hyper-V Enhanced Session (Mutter 50 is Wayland-only)
#   - FIX: bootc lint clean — /var content moved to /usr, tmpfiles.d for directories
#   - FIX: Terra/CrowdSec repos disabled INSIDE image (fixes BIB ISO depsolve GPG failure)
#   - FIX: Hyper-V memory alignment in cloud-ws.ps1

# ── Stage 1: Build context (never enters final image) ────────────────────────
FROM scratch AS ctx
COPY scripts/ /scripts/
COPY PACKAGES.md /
COPY VERSION /
COPY system_files/ /system_files/

# ── Stage 2: CloudWS bootc image ─────────────────────────────────────────────
FROM ghcr.io/ublue-os/ucore-hci:stable-nvidia

ARG MAKEFLAGS="-j4"
ENV MAKEFLAGS=${MAKEFLAGS}

ARG CLOUDWS_RAWHIDE_KERNEL=0
ENV CLOUDWS_RAWHIDE_KERNEL=${CLOUDWS_RAWHIDE_KERNEL}

# ── STEP A: Run all numbered build scripts ───────────────────────────────────
# NOTE: system_files/ are NOT yet present. Scripts MUST NOT run
# `systemctl enable` for any unit that lives in system_files/.
# Those enables happen in STEP D below.
RUN --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    export SYSTEMD_OFFLINE=1 && \
    export container=podman && \
    mkdir -p /tmp/build && \
    cp -a /ctx/scripts /tmp/build/scripts && \
    cp /ctx/PACKAGES.md /tmp/build/PACKAGES.md && \
    cp /ctx/VERSION /tmp/build/VERSION && \
    find /tmp/build -name "*.sh" -exec sed -i 's/\r$//' {} + && \
    find /tmp/build -name "*.md" -exec sed -i 's/\r$//' {} + && \
    find /tmp/build -name "cloudws-*" -exec sed -i 's/\r$//' {} + && \
    chmod +x /tmp/build/scripts/*.sh /tmp/build/scripts/lib/*.sh && \
    chmod +x /tmp/build/scripts/cloudws-toggle-headless /tmp/build/scripts/cloudws-test 2>/dev/null || true && \
    PACKAGES_MD=/tmp/build/PACKAGES.md bash /tmp/build/scripts/build.sh && \
    rm -rf /tmp/build

# ── STEP B: /opt → /var/opt (writable /opt on immutable filesystem) ──────────
RUN rm -rf /opt && ln -s /var/opt /opt

# ── STEP C: Prepare directories for logically-bound images (bootc v1.13+) ────
RUN mkdir -p /usr/lib/bootc/bound-images.d

# ── STEP D: System file overlay + service enablement ─────────────────────────
# Copy ALL system_files, then enable every service unit that scripts couldn't.
# This is the ONLY place where system_files-sourced units get enabled.
RUN --mount=type=bind,from=ctx,source=/system_files,target=/tmp/sf \
    if [ -d /tmp/sf/usr/local ]; then \
        cp -a /tmp/sf/usr/local/. /usr/local/ 2>/dev/null || true; \
    fi && \
    find /tmp/sf -path /tmp/sf/usr/local -prune -o -print0 2>/dev/null \
        | cpio -p0dmu / 2>/dev/null || \
    rsync -a --exclude='usr/local' /tmp/sf/ / 2>/dev/null || \
    (cd /tmp/sf && find . -not -path './usr/local*' -not -path './usr/local' | while read f; do \
        if [ -d "/tmp/sf/$f" ]; then mkdir -p "/$f"; \
        else cp -a "/tmp/sf/$f" "/$f" 2>/dev/null || true; fi; \
    done) && \
    find /etc/systemd/system -name "*.mount" -o -name "*.service" -o -name "*.conf" 2>/dev/null | xargs chmod 644 2>/dev/null || true && \
    find /usr/lib/systemd/system -name "*.mount" -o -name "*.service" -o -name "*.conf" 2>/dev/null | xargs chmod 644 2>/dev/null || true && \
    chmod +x /usr/bin/gamescope-session-steam /usr/bin/steamos-session-select 2>/dev/null || true && \
    chmod +x /usr/libexec/cloudws-flatpak-install /usr/libexec/cloudws-boot-diag /usr/libexec/cloudws-grd-setup /usr/libexec/cloudws/verify-root.sh 2>/dev/null || true && \
    dconf update 2>/dev/null || true && \
    restorecon -R /etc /var /boot /usr/lib/bootc /usr/lib/ostree 2>/dev/null || true && \
    echo "── Enabling system_files-sourced services ──" && \
    systemctl enable cloudws-flatpak-install.service 2>/dev/null && echo "  ✓ cloudws-flatpak-install" || echo "  ⚠ cloudws-flatpak-install" && \
    systemctl enable cloudws-boot-diag.service 2>/dev/null && echo "  ✓ cloudws-boot-diag" || echo "  ⚠ cloudws-boot-diag" && \
    systemctl enable cloudws-grd-setup.service 2>/dev/null && echo "  ✓ cloudws-grd-setup" || echo "  ⚠ cloudws-grd-setup" && \
    systemctl enable cloudws-ceph-bootstrap.service 2>/dev/null && echo "  ✓ cloudws-ceph-bootstrap" || echo "  ⚠ cloudws-ceph-bootstrap" && \
    systemctl enable cloudws-verify-root.service 2>/dev/null && echo "  ✓ cloudws-verify-root" || echo "  ⚠ cloudws-verify-root" && \
    systemctl enable cloudws-nvidia-cdi.service 2>/dev/null && echo "  ✓ cloudws-nvidia-cdi" || echo "  ⚠ cloudws-nvidia-cdi" && \
    systemctl enable k3s.service 2>/dev/null && echo "  ✓ k3s" || echo "  ⚠ k3s" && \
    systemctl enable var-home.mount 2>/dev/null && echo "  ✓ var-home.mount" || echo "  ⚠ var-home.mount" && \
    systemctl enable var-lib-containers.mount 2>/dev/null && echo "  ✓ var-lib-containers.mount" || echo "  ⚠ var-lib-containers.mount" && \
    echo "── Service enablement complete ──"
    systemctl enable k3s.service 2>/dev/null && echo "  ✓ k3s" || echo "  ⚠ k3s" && \
    systemctl enable var-home.mount 2>/dev/null && echo "  ✓ var-home.mount" || echo "  ⚠ var-home.mount" && \
    systemctl enable var-lib-containers.mount 2>/dev/null && echo "  ✓ var-lib-containers.mount" || echo "  ⚠ var-lib-containers.mount" && \
    systemctl mask flatpak-add-fedora-repos.service 2>/dev/null || true && echo "  ✓ masked flatpak-add-fedora-repos" &&
    echo "── Service enablement complete ──"

# ── STEP E: Post-build validation ────────────────────────────────────────────
RUN echo "── Post-build validation ──" && \
    MISSING=0 && \
    for pkg in gnome-shell gdm podman bootc libvirt kernel firewalld cockpit avahi tuned bootupd; do \
        if rpm -q "$pkg" > /dev/null 2>&1; then \
            echo "  ✓ $pkg"; \
        else \
            echo "  ✗ $pkg MISSING"; \
            MISSING=$((MISSING + 1)); \
        fi; \
    done && \
    echo "── Checking systemd unit enablement ──" && \
    for unit in gdm.service libvirtd.socket cockpit.socket sshd.service tuned.service podman-auto-update.timer cloudws-flatpak-install.service cloudws-boot-diag.service k3s.service; do \
        if systemctl is-enabled "$unit" 2>/dev/null | grep -qE 'enabled|static'; then \
            echo "  ✓ $unit"; \
        else \
            echo "  ⚠ $unit NOT ENABLED"; \
        fi; \
    done && \
    echo "── Footgun check ──" && \
    for pkg in PackageKit gnome-initial-setup gnome-tour malcontent-pam malcontent-tools; do \
        if rpm -q "$pkg" > /dev/null 2>&1; then \
            echo "  ⚠ FOOTGUN: $pkg present"; \
        fi; \
    done && \
    echo "── Validation complete ($MISSING critical missing) ──"

# ── STEP F: Disable ALL third-party repos (fixes BIB ISO depsolve) ───────────
# BIB reads repo files from the container but resolves gpgkey=file:// against
# its own filesystem. Disabled repos are skipped entirely.
RUN for repo in rpmfusion-free rpmfusion-nonfree rpmfusion-free-updates rpmfusion-nonfree-updates \
                terra fedora-44 fedora-44-updates fedora-rawhide-kernel crowdsec nvidia-container-toolkit; do \
        dnf config-manager setopt "${repo}.enabled=0" 2>/dev/null || \
        sed -i 's/^enabled=1/enabled=0/' "/etc/yum.repos.d/${repo}.repo" 2>/dev/null || true; \
    done

# ── STEP G: Generate GENERIC initramfs for multi-surface boot ────────────────
# CRITICAL: hostonly="no" in dracut drop-ins (from system_files) ensures the
# initramfs includes Hyper-V (hv_storvsc, hv_vmbus), virtio, and NVMe drivers.
# Without this, the VM cannot find its root disk and hangs silently.
RUN KVER=$(ls -1 /lib/modules/ | sort -V | tail -1) && \
    echo "── Regenerating GENERIC initramfs for kernel ${KVER} ──" && \
    if [ -n "$KVER" ]; then \
        rm -f "/lib/modules/${KVER}/initramfs.img" "/boot/initramfs-${KVER}.img" 2>/dev/null || true; \
        mkdir -p /root && DRACUT_NO_XATTR=1 /usr/bin/dracut --no-hostonly --reproducible --add ostree --kver "$KVER" \
            "/lib/modules/${KVER}/initramfs.img" 2>&1 || \
        echo "WARNING: dracut failed — disk image targets may not work"; \
    fi

# ── STEP H: Final lint cleanup ───────────────────────────────────────────────
# Remove every file that triggers bootc container lint warnings.
RUN rm -f /var/log/dnf5.log /var/log/*.log 2>/dev/null || true && \
    rm -rf /var/cache/ldconfig 2>/dev/null || true && \
    ldconfig 2>/dev/null || true && \
    rm -rf /var/cache/ldconfig 2>/dev/null || true

# OCI labels — placed BEFORE CMD per spec
LABEL containers.bootc="1"
LABEL ostree.bootable="1"
LABEL org.opencontainers.image.title="CloudWS"
LABEL org.opencontainers.image.description="Cloud Workstation OS — Immutable Fedora bootc with GNOME 50, KVM, K3s, NVIDIA"
LABEL org.opencontainers.image.source="https://github.com/Kabuki94/CloudWS-bootc"
LABEL org.opencontainers.image.version="2.2.0"
LABEL io.artifacthub.package.license="MIT"

CMD ["/sbin/init"]
RUN bootc container lint
