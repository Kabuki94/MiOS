# Changelog
All notable changes to this project will be documented in this file.

## [v0.1.1] - 2026-04-19

### 🛠️ Hardware & GPU Optimization
* **Intel Battlemage (Xe2) Support:** Implemented strict `kargs` bindings to force consumer Battlemage cards to utilize the modern `xe` driver, bypassing the legacy `i915` fallback trap.
* **RTX 50-Series (Blackwell) VFIO Fixes:** Mitigated the Blackwell GSP firmware initialization bug during GPU passthrough. Deployed `disable_idle_d3=1` kernel arguments and injected a dynamic `libvirt` QEMU hook to force Function Level Resets (FLR) on PCI host devices during VM state transitions.
* **NVIDIA Waydroid Hardware Fallback:** Waydroid Android containers will no longer crash on NVIDIA hosts. Added a dynamic detection hook that automatically steps NVIDIA hosts down to SwiftShader (CPU software rendering) for EGL and Vulkan.

### ⚙️ Core OS & Systemd Stabilization
* **WSL2 Execution Overhaul:** Resolved massive failure cascades on WSL2 kernels caused by `dbus-broker` audit subsystem hooks. Injected strict hypervisor gating and provided a native `dbus-daemon-wsl.service` fallback.
* **Ordering Cycle Fixes:** Cleanly broke closed dependency loops between `sockets.target` and custom GPU passthrough units.
* **ComposeFS Remount Bug:** Completely bypassed the Fedora 42+ `systemd-remount-fs` overlay rejection bug by permanently migrating root filesystem options directly to the kernel bootline.
* **Nested Virtualization:** Hardware virtualization instructions (VT-x/AMD-V) are now enabled globally in the kernel via `kvm_intel.nested=1`.
* **Execution Permissions & SUIDs:** Restored stripped `203/EXEC` executable bits for all internal `/usr/libexec/cloudws-*` binaries and fixed `systemd-resolved` user mappings.

### 🔒 Security & Identity Management
* **Native K3s SELinux Confinement:** Abandoned deprecated CentOS 8 RPMs. The `k3s-selinux` policy is now natively cloned, compiled into a `.pp` module against the active kernel headers, and embedded directly into the immutable OCI layer.
* **Fapolicyd `fs-verity` Integration:** Eliminated 5-minute hashing boot delays by migrating the Fapolicyd application whitelisting backend to inherently trust the `fs-verity` Merkle trees provided by Native ComposeFS.
* **Zero-Touch FreeIPA Enrollment:** Architected a `systemd` oneshot service that intercepts provisioning secrets at `/etc/cloudws/ipa-enroll.env`, automatically joins the domain on first boot, and securely shreds the credentials.
* **USBGuard Enforcement:** Enforced strict `0600` permissions on USBGuard configuration.

### 🐳 Containers & Local Environments
* **True Docker Daemon Support:** Resolved conflicts between `podman-docker` and `moby-engine`. CloudWS now explicitly ships the true Docker engine to support complex DevContainers.
* **Pacemaker HA Quadlet:** Migrated Corosync and Pacemaker Remote (`pcsd-remote`) to a privileged, host-networked Podman Quadlet.
* **Podman Desktop Integration:** Exposed essential developer ports (`22, 3389, 6443, 8080, 8443, 9090`) in the Containerfile and configured Cockpit to accept unencrypted local traffic for seamless port-forwarding.
* **Offline Firewall Provisioning:** Migrated all build-time firewalld configurations to `firewall-offline-cmd`.

### 🏗️ CI/CD & Supply Chain
* **Staged UKI Rendering:** Prepped the OCI image for Unified Kernel Images (UKI) and Secure Boot by executing `bootc container render-kargs` during the build.
* **Exhaustive Smoke Testing:** Overhauled `smoke-test.sh` to deeply validate structural image invariants, hardware hooks, and security files.
* **Full Stack Manifests:** The CI pipeline now generates and uploads a `cloudws-full-stack-report.log` artifact on every build.
* **Tag Triggers:** Refactored GitHub Actions to fully process, build, and sign `v*.*.*` release tags instead of ignoring them.
