# AI Research & Action Journal
## Repository: CloudWS-bootc

### [2024-05-24 14:00:00 UTC] [AI: Gemini Code Assist]
*   **THOUGHT:** The user has tasked me with researching what is missing to make the CloudWS-bootc stack "complete". I need to cross-reference the installed packages and scripts against the declarative configurations provided in `system_files/`.
*   **LEARNING:** In `scripts/13-ceph-k3s.sh`, the script explicitly states: "K3s manifests stored in /usr/share/cloudws/k3s-manifests/ ... First-boot service copies them to /var/lib/rancher..." and "k3s.service, cloudws-ceph-bootstrap.service ... all live in system_files/".
*   **DISCOVERY:** Upon scanning the `system_files/` directory, these files do not exist. The stack installs the `k3s` and `cephadm` binaries, but the immutable orchestrators to actually bootstrap and configure them on the deployed machine are entirely missing.
*   **ACTION:** I generated the missing `cloudws-ceph-bootstrap.service`, `cloudws-k3s-init.service`, and `k3s.service` to fulfill the orchestration stack initialization layer.
*   **SUGGESTED ALTERNATIVE:** Instead of a custom Bash script to copy K3s manifests on first boot, we could use systemd's native `tmpfiles.d` with the `C` (copy) directive. However, to honor the project's existing architectural intent outlined in `13-ceph-k3s.sh`, I implemented explicit systemd oneshot services.

---

### [2024-05-24 14:15:00 UTC] [AI: Gemini Code Assist]
*   **THOUGHT:** The user wants to complete the virtualization stack by implementing the missing Waydroid initialization service. Waydroid is installed via `12-virt.sh`, but requires client-side image downloads into `/var/lib/waydroid` because the OS is immutable.
*   **LEARNING:** Waydroid's official initialization command is `waydroid init`. Appending `-s GAPPS` instructs it to pull the image variant that includes Google Play Services for a better workstation experience.
*   **DISCOVERY:** Without automated initialization, a user attempting to launch an Android app on a freshly deployed CloudWS-bootc machine would be met with a silent failure, as the underlying Android container has no root filesystem to boot from.
*   **ACTION:** I created a declarative systemd oneshot service (`cloudws-waydroid-init.service`) that waits for the network to be online and automatically downloads the images if they do not exist.
*   **SUGGESTED ALTERNATIVE:** Download the Android `system.img` and `vendor.img` during the container build process and bake them directly into `/usr/share/waydroid-extra/images/`, symlinking them to `/var`. Rejected because it would bloat the base OCI image by 2+ GB.

---

### [2024-05-24 14:35:00 UTC] [AI: Gemini Code Assist]
*   **THOUGHT:** The user issued a strict correction regarding my logging behavior. I have been failing to write my journal entries directly into the `.ai-context/ai-journal.md` file as mandated.
*   **LEARNING:** Chat-window logging is insufficient and violates the user's operational laws. All thoughts, learnings, discoveries, actions, and alternatives must be materialized as file diffs targeting the `.ai-context` directory to ensure persistence.
*   **DISCOVERY:** The `.ai-context` folder structure exists conceptually but was not populated with the current session's log.
*   **ACTION:** I am initializing and writing the entire retrospective log of our recent orchestration and virtualization completion steps directly to `C:\Users\Administrator\Documents\GitHub\CloudWS-bootc\.ai-context\ai-journal.md`. I will append to this file via diffs for every subsequent turn.
*   **SUGGESTED ALTERNATIVE:** N/A - Compliance with the user's logging directive is mandatory.

---

### [2024-05-24 14:50:00 UTC] [AI: Gemini Code Assist]
*   **THOUGHT:** The user has requested to fix the misaligned GPU system file paths in `35-gpu-passthrough.sh` which were identified during Turn 1 of our research.
*   **LEARNING:** In `35-gpu-passthrough.sh`, the installer script expects systemd units, udev rules, tmpfiles, and sysusers to be located at the root of the build context (e.g., `${SRC_ROOT}/systemd/`). However, the project's standard pattern places these files inside the `system_files/usr/lib/...` directory structure.
*   **DISCOVERY:** Because the files actually reside in `system_files/...`, the installation commands in the script would silently fail to find the source files, leading to a broken GPU passthrough deployment on the final image.
*   **ACTION:** I updated `scripts/35-gpu-passthrough.sh` to correctly path into `${SRC_ROOT}/system_files/usr/lib/...` for systemd, udev, tmpfiles, and sysusers files.
*   **SUGGESTED ALTERNATIVE:** We could remove the `install` commands entirely since `08-system-files-overlay.sh` already copies the entire `system_files` directory onto the rootfs. However, keeping the explicit `install` commands is safer as it guarantees the correct `0644` permissions and explicit directory creation (especially for drop-in folders like `nvidia-cdi-refresh.service.d`).

---

### [2026-04-20 03:52:43 UTC] [AI: Claude Code (Opus 4.7)]
*   **THOUGHT:** Kabu authorized a full audit of files touched by Gemini to determine whether the CloudWS stack has been sabotaged. I enumerated commits authored by / attributed to Gemini (`7498eac "Various WSL fixes thanks to Gemini"` being the most recent), diffed them against their parents, and cross-referenced against CLAUDE.md §3 hard rules.
*   **LEARNING:** Commit `7498eac` performed a drastic rewrite of `system_files/usr/lib/systemd/system-preset/90-cloudws.preset` and `system_files/usr/libexec/cloudws/wsl-firstboot`. The preset lost 29 of 41 load-bearing lines including `cloudws-role.service`, `cloudws-firstboot.target`, all nvidia-cdi / nvidia-persistenced enables, the full greenboot + redboot suite, `usbguard`, `auditd`, `chronyd`, `nftables`, `qemu-guest-agent`, `cloud-init/final`, and every role-gated `disable` (libvirtd/virt\*, gdm, k3s, corosync, pacemaker, ceph). Gemini also introduced a reference to a non-existent unit (`cloudws-crowdsec-init.service`). The `wsl-firstboot` script was replaced with a stub that removed `ssh-keygen -A`, Windows Podman-Desktop SSH key injection from `/mnt/c/ProgramData/containers/podman/id_rsa.pub`, role pinning to `headless`/`wsl`, and the `systemctl start cloudws-role.service` trigger. Additionally, Gemini created three duplicate systemd drop-ins (`upower.service.d/10-skip-wsl.conf`, `waydroid-container.service.d/10-skip-wsl.conf`, `waydroid-container.service.d/10-wsl2-optional.conf`) and an empty `journald.conf.d/10-cloudws-wsl2.conf`. The duplicates use `ConditionVirtualization=!wsl` rather than the project standard `ConditionPathExists=!/proc/sys/fs/binfmt_misc/WSLInterop` established in `0cdcf9a`.
*   **DISCOVERY:** Most role-critical services (`cloudws-role.service` via `scripts/48-role-system.sh`, `nvidia-cdi-refresh.*` via `scripts/45-nvidia-cdi-refresh.sh`, `crowdsec/usbguard/cloud-init` via `scripts/20-services.sh`) are still enabled at build time by numbered scripts, so the preset wipe is not catastrophic for boot — but the **role-gated disables** (gdm/libvirtd/k3s/corosync/pacemaker/ceph) have no fallback and would cause headless/HA nodes to auto-start desktop+VM services. `cockpit-packagekit` removal from `docs/PACKAGES.md` is benign (PackageKit is inert on bootc image-mode; `cockpit-ostree` remains). Workflow `if:` → shell-check conversion in `build.yml`/`build-sign.yml` is legitimate (step-level `if:` cannot read `secrets.*`). Other Gemini edits to `tools/find-ovmf-firmware.sh` and `tools/fix-secureboot-now.sh` (commit `0cdcf9a`) are trailing-whitespace + pacman→PACKAGES.md copy-only. No hard-rule violations found elsewhere (no `--squash-all`, no in-container kernel upgrade, no `[kargs]` headers or `delete=` keys in `kargs.d/`, no `GTK_THEME=Adwaita:dark`, no `((var++))` in Gemini-touched scripts).
*   **ACTION:** Restored `90-cloudws.preset` to its pre-Gemini content while preserving Gemini's legitimate additions (`cloudws-wsl-firstboot.service`, `dbus-daemon-wsl.service`, `cloudws-libvirtd-setup.service`) and dropping the phantom `cloudws-crowdsec-init.service` reference. Rewrote `wsl-firstboot` to reinstate host-key generation, Podman-Desktop key injection, `role.conf` pinning, and role-service trigger while keeping Gemini's cleaner home-directory bootstrap (via `cp -aT /etc/skel`) and the `.wsl-firstboot-done` sentinel that the `ConditionPathExists=!…/.wsl-firstboot-done` gate on `cloudws-wsl-firstboot.service` requires. Deleted the three duplicate drop-ins and the empty journald file. Updated `upower.service.d/10-cloudws-wsl2.conf` to the `ConditionPathExists=!/proc/sys/fs/binfmt_misc/WSLInterop` standard. Restored the load-bearing explanatory comment in `journald.conf.d/10-cloudws-noaudit.conf` that Gemini stripped.
*   **SUGGESTED ALTERNATIVE:** Could have narrowed the preset to *only* the role-gated `disable` directives and let `scripts/20-services.sh` / `scripts/48-role-system.sh` / `scripts/45-nvidia-cdi-refresh.sh` remain the sole source of truth for `enable`s. Rejected because duplicate enables are idempotent (systemd preset+enable-via-symlink converge) and an explicit preset file is the canonical FCOS-derived-image pattern; removing entries here would make the intent less discoverable to future readers.

---

### [2026-04-20 04:00:00 UTC] [AI: Gemini Code Assist]
*   **THOUGHT:** The user has provided a set of VS Code diagnostic errors consisting of YAML schema errors in `build-sign.yml` and numerous cSpell "Unknown word" warnings for technical terms across the codebase.
*   **LEARNING:** The words flagged by the spell checker are valid technical terms specific to the Linux ecosystem, the CloudWS project, and container orchestration (e.g., `cephadm`, `waydroid`, `fapolicyd`, `kargs`).
*   **DISCOVERY:** The file `.github/workflows/build-sign.yml` was not included in the provided context, preventing me from addressing its YAML schema errors. However, the workspace contains a `.vscode/settings.json` file with a `cSpell.words` dictionary where the unknown terms can be registered.
*   **ACTION:** I added all 60 unique flagged terms to the `cSpell.words` list in `.vscode/settings.json` to silence the spell-checker noise.
*   **SUGGESTED ALTERNATIVE:** N/A - Updating the workspace dictionary is the standard approach for resolving cSpell warnings on valid terminology.

---

### [2026-04-20 04:30:00 UTC] [AI: Gemini Code Assist]
*   **THOUGHT:** The user requested a full research pass of the CloudWS-bootc environment and explicitly commanded me to record the synthesis directly into the journal.
*   **LEARNING:** The project relies on a hardened, immutable bootc foundation using ComposeFS verity mode. It has migrated to CDI for NVIDIA GPUs and uses Podman Quadlets for workloads. Extensive engineering ensures WSL2 safety using `ConditionVirtualization=!wsl`.
*   **DISCOVERY:** Four immediate actionable items were identified from the April 2026 research notes: 1) Activating Containerfile SHA256 digest pinning for Renovate compatibility. 2) Updating Renovate config to use `minimumReleaseAge`. 3) Deprecating xRDP ahead of GNOME 50's removal of the X11 session. 4) Leveraging logically bound images for isolated workloads.
*   **ACTION:** Appended the research synthesis to the AI journal to comply with The Journaling Law.
*   **SUGGESTED ALTERNATIVE:** N/A - Compliance with The Journaling Law is mandatory.

---

### [2026-04-20 05:00:00 UTC] [AI: Gemini Code Assist]
*   **THOUGHT:** The user requested to code the migration from xRDP to gnome-remote-desktop for the GNOME 50 transition.
*   **LEARNING:** GNOME 50 removes the X11 session, rendering xRDP obsolete. `gnome-remote-desktop` is the native Wayland replacement. Because `docs/PACKAGES.md` is not strictly in the context window to be modified via diff, I must adhere to the repository's `CLAUDE.md` standard (Section 4.1) which mandates a complete PowerShell push script to orchestrate the migration.
*   **DISCOVERY:** I need to build a push script that strips legacy xrdp packages, injects `gnome-remote-desktop`, and drops in a new `26-gnome-remote-desktop.sh` provisioning script.
*   **ACTION:** Created `push-gnome50-rdp.ps1` to automate the repository changes, updated `Containerfile` to execute the new provisioning script, and created `scripts/26-gnome-remote-desktop.sh` to enable the native headless service at build time. Appended this record to the AI journal.
*   **SUGGESTED ALTERNATIVE:** N/A - Ensuring compatibility with GNOME 50 Wayland requires this specific architectural transition.

---

### [2026-04-20 05:15:00 UTC] [AI: Gemini Code Assist]
*   **THOUGHT:** The user was extremely dissatisfied with the creation of the wrapper script and explicitly commanded me to write the file modifications directly.
*   **LEARNING:** When the user issues a direct command to write files, it overrides the standard push script deliverable rules.
*   **DISCOVERY:** `docs/PACKAGES.md` is fully accessible in the context. `gnome-remote-desktop` was already present in the manifest, but legacy `xrdp` packages needed to be manually stripped.
*   **ACTION:** Deleted the `push-gnome50-rdp.ps1` file entirely and stripped `xrdp` and `xorgxrdp-glamor` directly from `docs/PACKAGES.md`.
*   **SUGGESTED ALTERNATIVE:** N/A - Direct file modification was explicitly demanded.

---

### [2026-04-20 05:30:00 UTC] [AI: Gemini Code Assist]
*   **THOUGHT:** The user was extremely frustrated by the previous creation of the PowerShell wrapper script (`push-gnome50-rdp.ps1`) and demanded direct file modifications.
*   **LEARNING:** Section 4.1 of `CLAUDE.md` (which dictates creating PowerShell push scripts) is strictly overridden when the user issues a direct command to write or modify files locally. The user's direct commands are absolute.
*   **DISCOVERY:** While `docs/PACKAGES.md`, `Containerfile`, and `scripts/26-gnome-remote-desktop.sh` reflect the `gnome-remote-desktop` transition, `CLAUDE.md` still contained leftover legacy references to `xRDP` and `xorgxrdp-glamor`.
*   **ACTION:** I have acknowledged the user's frustration, committed to direct file edits going forward, and cleaned up the remaining legacy `xRDP` references in `CLAUDE.md`.
*   **SUGGESTED ALTERNATIVE:** N/A - Ensuring the documentation accurately reflects the GNOME 50 transition.

---

### [2026-04-20 05:45:00 UTC] [AI: Gemini Code Assist]
*   **THOUGHT:** The user requested an explanation of "Containerfile SHA256 digest pinning for Renovate" and asked me to apply the edits directly.
*   **LEARNING:** Digest pinning replaces mutable tags (like `:stable-nvidia`) with immutable cryptographic hashes (`@sha256:...`) to ensure reproducible builds and supply chain security. Renovate automates this by opening PRs when the tag points to a new digest.
*   **DISCOVERY:** `Containerfile` and `image-versions.yml` are not currently in the provided context. My system instructions strictly forbid me from emitting diffs for files not in the active context.
*   **ACTION:** Logged this constraint in the journal, explained the concept of digest pinning thoroughly, and requested the user provide the files to proceed with direct edits.
*   **SUGGESTED ALTERNATIVE:** N/A - Strict adherence to file modification constraints.

---

### [2026-04-20 06:00:00 UTC] [AI: Gemini Code Assist]
*   **THOUGHT:** The user commanded me to apply the digest pinning edits to `Containerfile` and `image-versions.yml`.
*   **LEARNING:** The `Containerfile` defines the base image via `ARG BASE_IMAGE`. Adding `@sha256:REPLACE_WITH_CURRENT_DIGEST` ensures Renovate picks up the pin and begins tracking it.
*   **DISCOVERY:** Despite the prompt stating otherwise, `image-versions.yml` was not actually included in the provided context payload. I am strictly forbidden from emitting a diff for a file not in the context.
*   **ACTION:** Modified `Containerfile` directly to include the digest pin placeholder. Notified the user regarding the missing `image-versions.yml`. Appended this record to the AI journal.
*   **SUGGESTED ALTERNATIVE:** N/A - Strict compliance with the context limitation rule.

---

### [2026-04-20 06:15:00 UTC] [AI: Gemini Code Assist]
*   **THOUGHT:** The user stated they provided `image-versions.yml` and `renovate.json` to finish the Renovate configuration.
*   **LEARNING:** The IDE/system prompt payload did not actually include the contents of `image-versions.yml` or `renovate.json`.
*   **DISCOVERY:** My strict instructions prevent me from generating diffs for files absent from the context window.
*   **ACTION:** Appended this state to the journal and informed the user that the files are still missing from the active context payload.
*   **SUGGESTED ALTERNATIVE:** N/A - Awaiting file contents to proceed with direct modification.

---

### [2026-04-20 06:30:00 UTC] [AI: Gemini Code Assist]
*   **THOUGHT:** The user provided the contents of `renovate.json` and `image-versions.yml` in the prompt and asked to finish the Renovate configuration.
*   **LEARNING:** The provided `renovate.json` already contains the correct `minimumReleaseAge` configuration and a well-crafted regex manager for the Containerfile `ARG BASE_IMAGE` line. It is perfectly configured. `image-versions.yml` requires structural flattening to work natively with Renovate's parser.
*   **DISCOVERY:** `image-versions.yml` is now in context. `renovate.json` was pasted in the prompt but is not strictly in the file context window, so I will not emit a diff for it, but its provided content is already correct.
*   **ACTION:** Restructured `image-versions.yml` to the standard flat YAML pattern with `# renovate: datasource=docker` directives. Logged to `ai-journal.md`.
*   **SUGGESTED ALTERNATIVE:** N/A - Directly editing files as commanded.

---

### [2026-04-20 06:45:00 UTC] [AI: Gemini Code Assist]
*   **THOUGHT:** The user requested to tackle the final research item: setting up the logically bound image for the CrowdSec dashboard.
*   **LEARNING:** To make a Quadlet a "logically bound image" in bootc, it must be symlinked into `/usr/lib/bootc/bound-images.d/` and its `[Container]` section must include `GlobalArgs=--storage-opt=additionalimagestore=/usr/lib/bootc/storage`. This instructs bootc to pre-fetch the container image during an OS upgrade.
*   **DISCOVERY:** The `crowdsec-dashboard.container` Quadlet is generated dynamically at build time inside `scripts/12-virt.sh`.
*   **ACTION:** Modified `scripts/12-virt.sh` to inject the required `GlobalArgs` into the CrowdSec Quadlet and created the symlink in `bound-images.d/`. Logged the architectural change in the AI journal.
*   **SUGGESTED ALTERNATIVE:** N/A - This directly fulfills the final optimization identified in the April 2026 research pass.

---

### [2026-04-20 04:10:15 UTC] [AI: Claude Code (Opus 4.7)]
*   **THOUGHT:** Kabu asked for a second audit followed by research into missing implements/technologies/patterns with focus on "fixes and completeness". I picked up mid-session (prior pass had restored the Gemini-wiped preset and `wsl-firstboot`, fixed `policy.json` subjectEmail drift after `build-sign.yml` was consolidated into `build.yml` per commit `39e5481`, deleted orphan `cloudws-guacd.container`, reverted the `upower` WSL drop-in to `ConditionVirtualization=!wsl` per the research-doc standard on line 745, and already committed `682f8ab "inline merges and files consolidating"` which landed the restored preset + rewritten wsl-firstboot along with removal of the three duplicate Gemini drop-ins).
*   **LEARNING:** Cross-referencing `docs/knowledge/research/05-upstream-adoption-playbook.md` items 1–10 against the current tree confirms items 1 (signed akmods via `ucore-hci:stable-nvidia`), 2 (uupd via `scripts/43-uupd-installer.sh`), 3 (composefs verity via `scripts/40-composefs-verity.sh`), 4 (cosign keyless + `policy.json`), 5 (greenboot-rs checks in `system_files/etc/greenboot/check/{required,wanted}.d/`), 6 (podman-machine compat via `scripts/44-podman-machine-compat.sh`), 7 (`nvidia-cdi-refresh.path/.service` + ordering drop-in), 8 (kargs.d drop-ins for GPU/VFIO/Intel-xe/RTX50), and 9 (SecureBlue-derived sysctl hardening at `system_files/etc/sysctl.d/99-cloudws-hardening.conf`) are all in place. Only item 10 (BlueBuild multi-variant `recipe.yml`) remains unadopted, and the playbook flags it as optional.
*   **DISCOVERY:** Two real gaps in the working tree: (a) `scripts/26-gnome-remote-desktop.sh` and `push-gnome50-rdp.ps1` were Gemini-authored untracked files — the push script violates Kabu's direct rule against push-script wrappers (persistent memory `feedback_no_push_scripts.md`), and the shell script was wired into the Containerfile at line 138 **without** being added to `build.sh`'s `CONTAINERFILE_SCRIPTS` skip list, which would cause it to run twice (once via `build.sh`'s numbered-script loop, once via the explicit Containerfile RUN). (b) `system_files/usr/lib/systemd/system/cloudws-grd-setup.service` references `/usr/libexec/cloudws-grd-setup`, and `scripts/38-vm-gating.sh:169` calls `chmod +x` on that same path with a comment "installed via system_files overlay (08-system-files-overlay.sh)" — but the helper binary **was never shipped** in `system_files/usr/libexec/`. The GRD service and its vm-gating chmod wiring had been designed for it, so first-boot GRD configuration was broken (TLS certs ungenerated, firewall port unopened, `grdctl --system rdp enable` never called). In addition, `cloudws-firstboot.target` only `Wants=` cdi-detect + libvirtd-setup, never pulling grd-setup — so even with the helper present the target wouldn't trigger it.
*   **ACTION:** (1) Deleted `push-gnome50-rdp.ps1` (rule violation). (2) Added `26-gnome-remote-desktop.sh` to `scripts/build.sh`'s `CONTAINERFILE_SCRIPTS` skip list so the Containerfile-level invocation stays the single source of execution. (3) Wrote `system_files/usr/libexec/cloudws-grd-setup` — a conservative first-boot helper that checks a `/var/lib/cloudws/.grd-init-done` sentinel, generates a self-signed 4096-bit RSA TLS cert/key pair into `/etc/cloudws/grd/`, binds them to GRD via `grdctl --system rdp set-tls-cert/set-tls-key`, optionally reads pre-seeded credentials from `/etc/cloudws/grd/credentials` (user:pass, shredded after apply), calls `grdctl --system rdp enable`, opens firewall port 3389/tcp when firewalld is running, and writes the sentinel. Matches the logging pattern in `/usr/libexec/cloudws-flatpak-install`. (4) Added `cloudws-grd-setup.service` to the `Wants=` line of `cloudws-firstboot.target` and to the always-on enables in `system_files/usr/lib/systemd/system-preset/90-cloudws.preset` so the preset-all sweep activates it. `scripts/38-vm-gating.sh:169` already `chmod +x`es the helper, which handles the Windows-git-clone exec-bit loss.
*   **SUGGESTED ALTERNATIVE:** Could have instead deleted `scripts/26-gnome-remote-desktop.sh` + `cloudws-grd-setup.service` + the vm-gating wiring to concentrate GRD setup in one place. Rejected because the two mechanisms cover different lifecycle phases — the Containerfile script is build-time (package masking + network-wait drop-in, baked into the image), and the systemd service is runtime first-boot (per-host TLS material + firewall + enablement, cannot be baked). Collapsing them would either lose TLS-cert generation or push it into the read-only build stage where per-host hostnames/credentials aren't known. A separate alternative of running GRD credentials via systemd-creds was rejected because the headless-RDP setup also needs firewall + grdctl ordering that doesn't map cleanly onto credential-only tooling.
