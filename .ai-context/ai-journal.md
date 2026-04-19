# AI Collaboration Journal
> This journal is maintained by AI agents (Gemini, Claude, etc.) operating in the CloudWS-bootc workspace. It acts as a shared memory of recent architectural discoveries, bug resolutions, and upstream research. Please append your findings here every turn or session.

## Entry: April 2026 - Bootc Ecosystem & Image Fixes (Gemini)

### 1. `bootc-image-builder` Filesystem Constraints
*   **Discovery**: `bootc-image-builder` (BIB) completely fails during the `org.osbuild.bootc.install-to-filesystem` stage if the `--rootfs` argument is set to `xfs` while the container image has `composefs.enabled = verity`.
*   **Root Cause**: XFS does not support `fsverity`, which is a strict requirement for ComposeFS's tamper-evident Merkle-tree root. This causes a superblock failure during the loopback mount.
*   **Resolution**: Hardcoded image build targets in `cloud-ws.ps1`, `iso.toml`, and internal configs have been migrated from `xfs` to `ext4`. `btrfs` is also a valid alternative. 

### 2. WSL2 / Podman Export Limitations
*   **Discovery**: Exporting a WSL2 tarball via `podman export` strips out all container volume contents. Because OSTree/bootc images (like `ucore-hci`) define `/var` as a volume, any user home directories (e.g., `/var/home/cloudws`) created during the Containerfile build are permanently lost.
*   **Secondary Discovery**: Forcing WSL to boot into a secondary `core` user and `su -` switching to the primary user strips the `WAYLAND_DISPLAY` and `DISPLAY` variables dynamically injected by WSLg, completely breaking GUI applications.
*   **Resolution**: 
    1. Changed the default login user in `system_files/etc/wsl.conf` directly to `cloudws`.
    2. Overhauled `wsl-firstboot` systemd service to dynamically recreate missing home directories from `/etc/skel` for both `core` and `cloudws` on the very first boot, side-stepping the podman export data loss entirely.

### 3. Container File Permission Stripping (The `/sbin/init` bug)
*   **Discovery**: Using `find /etc/systemd /usr/lib/systemd -type f -exec chmod 644 {} \;` globally recursively strips the executable bit from binaries nested in those folders. 
*   **Impact**: `/usr/lib/systemd/systemd` (which `/sbin/init` symlinks to) became non-executable, throwing `OCI permission denied` upon container boot.
*   **Resolution**: The `find` command in `scripts/08-system-files-overlay.sh` is now strictly constrained via `-name` flags to only target configuration files (`*.service`, `*.socket`, `*.conf`, etc.). 

### 4. Upstream Research: UKI & systemd-remount-fs
*   **systemd-remount-fs Bug**: On Fedora 42+, `systemd-remount-fs.service` crashes on boot because the kernel prevents remounting the ComposeFS overlay with new options from `/etc/fstab`. The workaround is masking the service (which we do in `40-composefs-verity.sh`). We must monitor Fedora 44+ to see if upstream patches systemd to target `/sysroot` instead.
*   **Unified Kernel Images (UKI)**: `bootc` is migrating to UKI as the standard for Secure Boot. UKIs bundle the kernel, initramfs, and `kargs` into a single EFI binary. RHEL 10 and Fedora 44 are building tooling (`bootc container render-kargs`) for this. 
*   **Next Steps for UKI**: CloudWS needs to figure out how to compile the TOML arrays in `kargs.d/` and our out-of-tree `akmod-nvidia` drivers into the UKI binary natively. 
*   **Hardlinking `/usr`**: Fedora 44 will globally hardlink identical files under `/usr`. Our `tar` overlay pipe in `08-system-files-overlay.sh` is safe because `bootc-base-imagectl rechunk` (which we run at the end of the build in `cloud-ws.ps1`) natively deduplicates and restores identical hardlinks across the image layers.

## Entry: April 2026 - Missing Components Deep Dive (Gemini)

I have conducted a deep dive into the remaining missing architectural components identified in the project Kanban board (`docs/RESEARCH_PLAN.md`). Here are the actionable paths forward for implementation:

### 1. `k3s-selinux` on Fedora 44
*   **The Gap**: `k3s-selinux` is not natively available in Fedora Rawhide (44/45). Our cluster deployment currently leaves K3s without strict confinement.
*   **The Implementation Path**: We must use the official Rancher RPM repository for CentOS 8/9 (`https://rpm.rancher.io/k3s/stable/common/centos/8/noarch`). We can add a `.repo` file to `system_files/etc/yum.repos.d/` or have `scripts/13-ceph-k3s.sh` directly fetch and install the RPM using `dnf install -y https://rpm.rancher.io/k3s/stable/common/centos/8/noarch/k3s-selinux-1.5-1.el8.noarch.rpm`.

### 2. `cosign` Verification for `bootc` Images
*   **The Gap**: We want `bootc switch --enforce-container-sigpolicy` using `cosign`, but the package is missing from Fedora 44 repos.
*   **The Implementation Path**: We have two options: (1) Enable the community COPR `shibumi/cosign` in our `05-enable-external-repos.sh` script, or (2) pull the static binary directly from the official Sigstore GitHub releases during the build phase and place it in `/usr/local/bin`. The binary download is the safest method to guarantee we get the latest stable version without relying on third-party COPRs.

### 3. Application Whitelisting (`fapolicyd` Alternatives)
*   **The Gap**: `fapolicyd` was removed from `PACKAGES.md` because it caused a 2-5 minute boot delay.
*   **The Finding**: `fapolicyd` actually *is* the most lightweight, native application whitelisting solution for Fedora (utilizing the kernel's `fanotify` API). The extreme boot delay was likely caused by it hashing every single binary on the system upon start. 
*   **The Implementation Path**: If we reintroduce it, we must strictly configure it to use its **RPM database trust backend**. When properly configured, `fapolicyd` trusts anything installed via `dnf` natively, requiring zero hashing overhead at boot time. Alternatives like SELinux MAC or IMA are vastly heavier and more complex to maintain for a desktop workstation.

### 4. NVIDIA Waydroid 3D Hardware Acceleration
*   **The Gap**: Waydroid Android containers on CloudWS-OS currently lack full 3D acceleration for NVIDIA users.
*   **The Finding**: This is a hard technical limitation upstream in 2025/2026. Waydroid's Android container strictly expects a Mesa-compatible driver (like `virtio-gpu`, `iris`, or `radeonsi`). NVIDIA's proprietary closed-source driver stack cannot talk directly to the Android container's Mesa expectations.
*   **The Implementation Path**: 
    1. For single-GPU NVIDIA systems: Force Waydroid to use `SwiftShader` (CPU software rendering). Add `ro.hardware.egl=swiftshader` to `/var/lib/waydroid/waydroid.cfg`.
    2. For hybrid laptops (Intel/AMD iGPU + NVIDIA): Waydroid must be run on the integrated Mesa-compatible GPU to achieve hardware acceleration. 

### 5. RTX 50-Series (Blackwell) VFIO Reset Bug
*   **The Gap**: The documentation warns about an active reset bug forcing a fallback to open kernel modules.
*   **The Finding**: There is sparse public upstream tracking of this specific bug under that exact name. 
*   **The Implementation Path**: We must closely monitor the `NVIDIA/open-gpu-kernel-modules` repository on GitHub for VFIO reset patches on the Blackwell architecture and ensure we are building the absolute latest `akmod-nvidia` drivers in our CI/CD pipeline.

*(End of Entry)*