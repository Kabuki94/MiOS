# CloudWS v2.0 — Containerfile
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
# BUILD SCRIPTS (modularized):
#   01-repos.sh        Fedora 44 overlay, RPMFusion, Terra, CrowdSec
#   02-kernel.sh       Kernel extras, headers, KVER capture
#   10-gnome.sh        GNOME 50 desktop, Flatpaks, Bibata cursor, Geist font
#   11-hardware.sh     GPU drivers (Mesa, NVIDIA verify, ROCm)
#   12-virt.sh         KVM, containers, Cockpit, gaming, Looking Glass
#   13-ceph-k3s.sh     Ceph distributed storage + K3s Kubernetes
#   20-services.sh     systemd service enable/gating
#   30-locale-theme.sh skel/.bashrc, GTK/Qt/Electron dark theme
#   31-user.sh         PAM, user creation, groups, sudoers
#   32-hostname.sh     Unique per-instance hostname (systemd wildcard)
#   33-firewall.sh     Firewall init script
#   34-gpu-detect.sh   GPU auto-detect service
#   35-init-service.sh Every-boot init, Podman GC timer, Avahi/mDNS
#   36-tools.sh        cloudws CLI + all management tools
#   37-selinux.sh      SELinux policy modules
#   38-vm-gating.sh    VM service gating, Hyper-V enhanced session, xRDP
#   39-desktop-polish.sh Cockpit webapp, fastfetch, MOTD, desktop entries

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

# /opt → /var/opt: writable /opt on immutable filesystem
RUN rm -rf /opt && ln -s /var/opt /opt

# System file overlay (dconf, systemd units, modprobe.d, sysctl, etc.)
# NOTE: On ucore, /usr/local is a symlink → /var/usrlocal. cp -a cannot
# overwrite a symlink with a directory, so we handle /usr/local separately.
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
    dconf update 2>/dev/null || true && \
    restorecon -R /etc /var /boot 2>/dev/null || true

# Post-build validation
RUN echo "── Post-build validation ──" && \
    for pkg in gnome-shell gdm podman bootc libvirt kernel firewalld cockpit avahi; do \
        rpm -q "$pkg" > /dev/null 2>&1 || echo "WARNING: $pkg not installed"; \
    done && \
    echo "── Validation complete ──"

# Disable third-party repos post-build (Bazzite pattern)
RUN dnf config-manager setopt rpmfusion-free.enabled=0 2>/dev/null || true && \
    dnf config-manager setopt rpmfusion-nonfree.enabled=0 2>/dev/null || true && \
    dnf config-manager setopt rpmfusion-free-updates.enabled=0 2>/dev/null || true && \
    dnf config-manager setopt rpmfusion-nonfree-updates.enabled=0 2>/dev/null || true && \
    dnf config-manager setopt terra.enabled=0 2>/dev/null || true && \
    dnf config-manager setopt fedora-44.enabled=0 2>/dev/null || true && \
    dnf config-manager setopt fedora-44-updates.enabled=0 2>/dev/null || true && \
    dnf config-manager setopt fedora-rawhide-kernel.enabled=0 2>/dev/null || true

# Generate initramfs for BIB compatibility.
RUN KVER=$(ls -1 /lib/modules/ | sort -V | tail -1) && \
    echo "── Generating initramfs for kernel ${KVER} ──" && \
    if [ -n "$KVER" ] && [ ! -f "/lib/modules/${KVER}/initramfs.img" ] && \
       [ ! -f "/boot/initramfs-${KVER}.img" ]; then \
        dracut --force --kver "$KVER" "/boot/initramfs-${KVER}.img" 2>&1 || \
        echo "WARNING: dracut failed — BIB disk image targets may not work"; \
    else \
        echo "── initramfs already exists for ${KVER} ──"; \
    fi

LABEL containers.bootc 1
LABEL ostree.bootable 1
CMD ["/sbin/init"]
RUN bootc container lint
