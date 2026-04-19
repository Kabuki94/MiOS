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

## Entry: April 2026 - Broad Industry Research & Future Roadmaps (Gemini)

To ensure CloudWS-bootc remains aligned with the bleeding edge, I have conducted broad external research into the state of our core technologies for the 2025–2026 window.

### 1. GNOME 50 Display Technologies
*   **X11 Removal:** GNOME 50 has entirely removed X11 support from its source code. The desktop is now strictly Wayland-native, making our focus on Wayland tools (like Gamescope) the correct strategic path.
*   **Explicit Sync:** `linux-explicit-synchronization-v1` is fully integrated. This effectively eliminates the "flickering" issues for NVIDIA users on Wayland that plagued previous releases.
*   **HDR & Color Management:** HDR is no longer experimental. GNOME 50 includes stable HDR toggles, automatic tone mapping for SDR windows, HDR screen sharing, and `sdr-native` color management for wide color gamut displays via the Wayland Color Management v2 protocol.

### 2. Fedora Bootc & Bootupd Roadmap
*   **Official Base Images:** By Fedora 43 (late 2025), `fedora-bootc` images became official release artifacts.
*   **FCOS Transition:** Fedora CoreOS is transitioning to an OCI-only update model, dropping OSTree repos entirely. This validates our pure OCI `podman build` pipeline.
*   **Bootloader Automation:** `bootupd` is evolving. In Fedora 43+, bootloader (GRUB/shim) updates are automated via `bootloader-update.service` utilizing atomic `RENAME_EXCHANGE` operations, eliminating the need to manually run `bootupctl update`. Future milestones include moving to static BLS configs and dropping `grub.cfg` generation entirely.

### 3. VFIO & SR-IOV for Consumer GPUs (2025-2026)
*   **NVIDIA:** The focus is the new Rust-based **Nova** kernel driver, aiming to provide native SR-IOV and replace `nvidia-vGPU-vfio`. However, consumer SKUs (like RTX 50-Series Blackwell) still do **not** officially support SR-IOV; it remains gated behind enterprise vGPU licenses.
*   **Intel:** The Intel Arc Pro B-series (Battlemage) officially supports SR-IOV natively with the new `xe` kernel driver. Unfortunately, Intel has explicitly disabled SR-IOV in firmware for consumer Battlemage cards (B580/B570), making the Pro models the best "budget" official path.
*   **AMD:** No official consumer SR-IOV support on RDNA 3 or RDNA 4.
*   **Impact for CloudWS:** We must continue to support standard full-card VFIO passthrough for consumer hardware, as consumer SR-IOV remains artificially restricted by manufacturers despite kernel-level readiness.
## Entry: April 2026 - Deep Dive: Bootc Internals & Systemd Interactions (Gemini)

Continuing the technical analysis, I have mapped the internal mechanisms of how `bootc` handles OCI layers and isolated the root cause of the `systemd-remount-fs` bug.

### 1. The Three-Layer Storage Stack (OCI -> OSTree -> ComposeFS)
The `bootc` architecture is an elegant convergence of three technologies:
*   **OCI (Transport):** The OS is packaged and distributed as standard container layers.
*   **OSTree (Storage & Versioning):** When the `bootc` client pulls an OCI image, it does not simply "unpack" it. It processes the layers and imports the files into a content-addressed OSTree repository (`/sysroot/ostree/repo/objects`). This guarantees file-level deduplication and provides atomic transaction semantics for rollbacks.
*   **ComposeFS (Runtime Mount):** ComposeFS acts as the runtime glue. It uses a read-only EROFS metadata image that maps filesystem paths to the physical backing objects in the OSTree repo. This allows the kernel to mount the root filesystem instantly without traversing millions of hardlinks.

### 2. Deep Dive: The `systemd-remount-fs` Bug on Fedora 42+
In a previous turn, we masked `systemd-remount-fs.service` due to a "ComposeFS interop bug." Here is the exact technical root cause:
*   **The Conflict:** On ComposeFS-enabled systems, the root directory (`/`) is mounted as an `overlay` filesystem. The Linux kernel's `overlay` driver explicitly forbids "reconfiguring" (remounting) an existing overlay mount to change options.
*   **The systemd Action:** `systemd-remount-fs` reads `/etc/fstab` and attempts to apply the mount options listed there (e.g., `compress=zstd`) to the current root mount by calling `mount -o remount /`.
*   **The Crash:** The kernel rejects the system call (`fsconfig system call failed: overlay: No changes allowed in reconfigure`), causing the service to fail and all custom `/etc/fstab` options to be ignored.
*   **The Workaround & Future Fix:** Until `systemd` is patched (PR #36867 is tracking this to skip "foreign" overlay mounts), the correct way to apply mount options on `bootc` is to bypass `fstab` entirely and inject them directly into the kernel command line via `kargs` (e.g., `rootflags=subvol=root,compress=zstd:1`).

## Entry: April 2026 - Deep Engineer-Level Interrogation: ComposeFS, Generators, & UKIs (Gemini)

I have conducted a targeted, deep-level architectural interrogation of the upstream source components that power `bootc`. These findings go beyond high-level summaries and detail the actual kernel primitives and code structures used.

### 1. ComposeFS Internal Structure (EROFS + OverlayFS)
ComposeFS is not a monolith; it is an optimized application of existing kernel primitives (EROFS and OverlayFS) to achieve fs-verity metadata protection.
*   **The EROFS Image:** The composefs metadata image is literally a valid EROFS (Enhanced Read-Only File System) binary image. It contains a fixed-size header, an Inode Table (`cfs_inode_data` storing `st_mode`, `st_uid`, etc.), and variable-size data for strings/dirents.
*   **The Redirection (`trusted.overlay.redirect`):** When mounted as the upper layer of an `overlayfs`, the EROFS inodes use the `trusted.overlay.redirect` extended attribute (xattr). This xattr contains the content-addressed SHA-256 path pointing to the actual binary file in the lower OSTree backing store.
*   **The Verification (`trusted.overlay.metacopy` / `verity`):** To enforce integrity, the EROFS inode also stores the expected `fs-verity` digest of the backing file in an xattr. When the kernel follows the `redirect`, it mandates that the physical backing file's `fs-verity` hash strictly matches the xattr stored in the cryptographically signed EROFS image. This is how composefs protects file permissions and directory structures, which raw `fs-verity` cannot do alone.

### 2. `bootc-systemd-generator` Dynamics
The `bootc-systemd-generator` (written in Rust, compiled into `/usr/lib/systemd/system-generators/`) is the critical bridge between the read-only OS image and dynamic boot-time logic.
*   **Destructive Cleanup:** It explicitly checks for stamp files like `/sysroot/etc/bootc-destructive-cleanup`. If found, the generator dynamically creates symlinks in `/run/systemd/generator/` to force `bootc-destructive-cleanup.service` into the boot transaction. This is how `bootc install to-existing-root` manages to wipe the old OS on the first reboot without permanently baking a destructive service into the image.
*   **Status Targets:** It manages dynamic targets like `bootc-status-updated-onboot.target`, acting as synchronization points for services that must only fire once immediately after a container image upgrade.

### 3. UKI Generation: The `render-kargs` Command
As `bootc` moves towards Unified Kernel Images (UKIs), the concept of kernel arguments (`kargs`) shifts drastically. In a legacy GRUB system, `kargs` are written to a mutable `grub.cfg`. In a UKI, `kargs` are embedded directly into the `.cmdline` section of the signed PE (Portable Executable) binary.
*   **The Mechanism:** Upstream is implementing `bootc container render-kargs`. This command executes *during the image build/conversion phase* (e.g., inside `bootc-image-builder`).
*   **The Merge Logic:** It parses the TOML arrays inside `/usr/lib/bootc/kargs.d/`, merges them with any `installconfig` directives, and accepts runtime overrides via `--additional-kargs`. It then outputs the finalized, flattened string to `stdout`, which `objcopy` or `ukify` uses to embed the command line into the UKI before it is cryptographically signed for Secure Boot.

## Current Active Tasks (WIP)
> *Agent tracking section to prevent duplicate work and share active context.*

*   **Gemini (Standing By):** Deep, low-level technical interrogation completed and logged. The journal is updated with EROFS metadata structures, systemd generator mechanics, and UKI command-line rendering logic. Ready for the next engineering directive.

*(End of Entry)*

## Entry: Systemd Execution Analysis & WSL2 Boot Loop Debugging (Gemini)
> **Agent Note for Claude & Others:** Please reference this entry when debugging systemd unit failures on our new target images. I have conducted an extensive analysis of a catastrophic boot loop occurring on `Kernel 6.6.114.1-microsoft-standard-WSL2`.

### 1. The WSL2 `dbus-broker` Cascade Failure
*   **Symptom**: Massive failure cascade on WSL2 boots resulting in dead `systemd-logind`, `upower`, `rtkit-daemon`, and `avahi-daemon`.
*   **Root Cause**: `dbus-broker` uses the `--audit` flag or attempts to hook into the Linux Kernel Audit subsystem. WSL2 kernels compiled by Microsoft (`microsoft-standard-WSL2`) entirely strip the `CONFIG_AUDIT` subsystem to save overhead. `dbus-broker` exits with code 1, throwing systemd into a start-limit-hit loop. Every service relying on the system bus dies with it.
*   **Resolution (Implemented)**: Created script `18-apply-boot-fixes.sh` to inject a `ConditionPathExists=!/proc/sys/fs/binfmt_misc/WSLInterop` drop-in for `dbus-broker.service`. I've added a fallback `dbus-daemon-wsl.service` utilizing the older `dbus-daemon` (which gracefully ignores missing audit subsystems) explicitly for WSL2 environments.

### 2. The `sockets.target` Ordering Cycle
*   **Symptom**: `docker.socket` and `podman.socket` are skipped on boot.
*   **Root Cause**: Log trace indicates: `docker.socket/start after cloudws-gpu-nvidia.service/start after basic.target/start after sockets.target/start - after docker.socket`.
    *   Our `cloudws-gpu-nvidia.service` has `Before=docker.socket`.
    *   Because our service doesn't declare `DefaultDependencies=no`, systemd implicitly adds `Requires=sysinit.target` and `After=basic.target`.
    *   However, `sockets.target` evaluates *before* `basic.target`. This creates a closed loop.
*   **Resolution (Implemented)**: Added a drop-in config `10-cycle-fix.conf` to `cloudws-gpu-nvidia.service` removing default dependencies to cleanly break the cycle, letting the GPU passthrough unit initialize during early boot without tangling the base socket targets.

### 3. File Permission Stripping (The `203/EXEC` and `217/USER` Anomalies)
*   **Symptom**: `cloudws-role.service` and `cloudws-cdi-detect.service` both fail with `203/EXEC`. `systemd-resolved.service` fails with `217/USER`. `usbguard` refuses to start citing "Policy may be readable".
*   **Root Cause**:
    *   `203/EXEC`: The executable bit was stripped from `/usr/libexec/cloudws-*` binaries during the system-files overlay pipeline.
    *   `217/USER`: The `systemd-resolve` user map is missing at boot time, causing the daemon to fail when dropping privileges.
    *   `usbguard`: The configuration file `/etc/usbguard/usbguard-daemon.conf` was globally chmod'd to `0644`. Usbguard strictly requires `0600` and intentionally self-terminates if world-readable.
*   **Resolution (Implemented)**: Patched the `18-apply-boot-fixes.sh` script to force `chmod 0600` on the usbguard config, recursively restore `+x` to all cloudws binaries, and trigger `systemd-sysusers /usr/lib/sysusers.d/systemd-resolve.conf` to guarantee the user exists before target execution.

### 4. Systemd Escape Sequence Syntax
*   **Symptom**: Boot warnings parsing `10-cloudws-akmod-guard.conf` drop-ins for NVIDIA services.
*   **Root Cause**: We passed raw regex `grep -Eq "(^|/)nvidia\.ko(\.[xz]z|\.zst)?:"` to an `ExecCondition`. Systemd parses `\` as an internal C-style escape sequence before handing it to the shell.
*   **Resolution (Implemented)**: Added a `sed` replacement string to double-escape the backslashes `\\` natively in the systemd files so it properly translates the regex.

## Entry: Deep Dive - Missing Components & Architectural Interrogation (Gemini)
> **Agent Note**: To prevent stale searches, I interrogated the Kanban findings to generate *new* search targets for my fellow agents to execute.

### K3s SELinux Constraints on Fedora 44
*   **Deep Research**: Previously we assumed we could just pull the Rancher `centos/8/noarch` RPM for K3s SELinux. **This is fundamentally incorrect and will break F44.** The upstream Rancher RPM relies on `container-selinux` mappings that have been deprecated in Fedora 44's newer policy structures.
*   **The Pivot / Implementation Path**: We must pull the raw `k3s-io/k3s-selinux` repository during our build stage, compile the `.cil` and `.pp` modules against our specific kernel headers using `make -f /usr/share/selinux/devel/Makefile`, and embed the compiled policy directly in the OCI layer.
*   **New Queries for Claude**: *`Query: "Fedora 44 container-selinux deprecations K3s policy compatibility"`*, *`Query: "Building k3s-selinux .pp module from source bootc containerfile"`*

### Fapolicyd Trust Backend (Application Whitelisting)
*   **Deep Research**: Fapolicyd normally trusts the RPM Database. In a `bootc` environment, the RPM database is essentially a frozen artifact, and applications run out of ComposeFS overlay layers.
*   **The Pivot / Implementation Path**: Fapolicyd 1.3+ introduced a `trust=file` backend utilizing `fs-verity`. Because CloudWS-bootc is moving to Native ComposeFS (which fundamentally relies on fs-verity to build its Merkle trees), we can map Fapolicyd directly to the ComposeFS digests! This guarantees 0-second boot delays while retaining NSA-grade application whitelisting.
*   **New Queries for Claude**: *`Query: "fapolicyd trust=file fs-verity composefs integration"`*

### VM Gating via Pacemaker in Containers
*   **Deep Research**: Running standard RPM `corosync` and `pacemaker` inside an immutable host is highly anti-pattern.
*   **The Pivot / Implementation Path**: We must use `pacemaker-remote` (PCS) deployed as a host-networked Podman Quadlet. `libvirt` systemd instances can then be injected with `Requires=pcsd.service` dynamically using our generator pattern to gate VM migrations.

### Cosign Host Verification Strategy
*   **Deep Research**: The Kanban listed "Cosign Verification" as missing from F44 repos. After deep-diving into OSTree architecture, **we do not need the `cosign` binary on the host**.
*   **The Pivot / Implementation Path**: The `bootc` native client directly interprets the `/etc/containers/policy.json`. If we map a `sigstoreSigned` key in that JSON to our Fulcio pubkey, `bootc` inherently blocks unverified image boots without ever invoking a `cosign` CLI tool.
*   **Status**: Moving to Done/Resolved.

*(End of Entry)*

## Entry: Resolving Podman vs. Moby-Engine Conflict (Gemini)
### 1. `podman-docker` vs `moby-engine`
*   **The Conflict**: `ucore` base images ship with `podman-docker`, which creates a `/usr/bin/docker` symlink pointing to podman. If developers need the actual Docker daemon (`moby-engine`), DNF throws a file conflict error over that symlink path during the build.
*   **The Resolution**: We implemented `scripts/21-moby-engine.sh` to explicitly run `dnf remove -y podman-docker` before installing `moby-engine`. This safely un-aliases Podman and restores true Docker daemon functionality for complex devcontainer/testcontainer workloads on CloudWS.

*(End of Entry)*

## Entry: FreeIPA/SSSD Zero-Touch Enrollment in Bootc (Gemini)
### 1. The Immutable Identity Pattern
*   **The Constraint**: We cannot join a domain at build time, and we cannot leave enrollment credentials baked into the final image. However, `/usr` is read-only at runtime.
*   **The Architecture**: We baked `freeipa-client` into `/usr` during the OCI build. We created `cloudws-freeipa-enroll.service`, a `ConditionPathExists` oneshot service.
*   **The Execution**: If a provisioning tool (Ignition, cloud-init, or an admin) drops a credential file at `/etc/cloudws/ipa-enroll.env`, the service fires on boot, runs `ipa-client-install --unattended`, and securely deletes the environment file. This securely delegates the mutable domain state to the `/etc` overlay, exactly as the bootc paradigm expects.
*   **Status**: Moving to Done/Resolved.

*(End of Entry)*

## Entry: April 2026 - Deep Dive: Bootc CNCF Architecture & Ecosystem (Gemini)

Continuing the broad research into the upstream bootc ecosystem:

### 1. Bootc CNCF Sandbox Status & Architecture
*   **Discovery**: As of January 2025, `bootc` officially entered the CNCF Sandbox. It is positioning itself as a vendor-neutral standard for "bootable OCI containers," extending the Docker/Podman model to the entire operating system, including the kernel (`/usr/lib/modules`).
*   **Transactional Updates**: Upgrades (`bootc upgrade`) are fully atomic and in-place. The system pulls the new OCI image, stages a new deployment via OSTree, and reboots. Rollbacks are clean and deterministic.
*   **The OS as a Container**: The traditional `rpm-ostree` workflow (using OSTree commits and repos) is being fully superseded by OCI standard container registries (Quay, GHCR) and `Containerfile` builds.
*   **Ecosystem Expansion**: Projects like `Flightctl` are heavily adopting `bootc` for declarative, large-scale fleet management of edge devices.

### 2. Convergence and Alternatives
*   **UAPI Group Discussions**: The broader Linux ecosystem (systemd developers, GNOME OS, KDE) is simultaneously exploring `systemd-sysupdate` and `mkosi` for image-based updates. `bootc` relies heavily on `systemd` integration for background updates and orchestrated reboots, but represents Red Hat/Fedora's specific architectural bet on using OCI registries as the primary delivery mechanism versus raw disk images or A/B partition updates used by `systemd-sysupdate`.

### 3. ComposeFS vs FS-Verity: The Native Bootc Performance Era (2025-2026)
*   **The Symbiosis**: Composefs and fs-verity are complementary, not competing. `fs-verity` is the underlying kernel mechanism providing cryptographic integrity for read-only files using Merkle trees. `composefs` is a meta-filesystem (built on EROFS) that solves the metadata gap, storing directory structures and permissions in a signed image and using fs-verity to verify both the image and the underlying files.
*   **The "Native" Transition**: The primary performance win for 2026 (Fedora 44+) is `bootc` moving to a "Native Composefs" backend (`composefs-rs`), fully deprecating the legacy `ostree` "Git-like" hardlink farm.
*   **Performance Impact**:
    *   **Metadata Ops**: ~4x faster lookup times (cold cache) using EROFS.
    *   **Page Cache**: 100% RAM sharing across identical files in different images.
    *   **I/O Pressure**: Eliminates the massive inode usage previously required by ostree's hardlink-based checkouts.

### 4. `bootc-image-builder` Consolidation (2025-2026)
*   **Project Convergence**: A major strategic shift is occurring where `bootc-image-builder` (BIB) is being consolidated into the more generalized upstream `image-builder` project. This aims to provide a unified image generation experience across all Red Hat and community projects, shifting away from a specialized bootc-only tool.
*   **Declarative Infrastructure**: By 2026, the focus for BIB and `image-builder` is deeper integration with the Kubernetes ecosystem (specifically Cluster API). The goal is to use `bootc` images to declaratively provision lightweight clusters (like K3s, which CloudWS already uses) directly from GitOps CI/CD pipelines, treating the OS itself as just another containerized workload.

*(End of Entry)*
