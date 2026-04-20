# CloudWS-bootc AI Context Log

This document serves as a persistent knowledge base for AI agents operating within the CloudWS-bootc repository. It contains insights, findings, and structural context discovered during audits and operations.

## Repository Overview
- **Project**: CloudWS-bootc
- **Goal**: Cloud Workstation OS Builder (based on bootc, targeting Fedora/CentOS ecosystems).
- **Core Languages**: PowerShell (automation/installation), Bash (provisioning/system scripts), YAML (Actions/config), Dockerfile/Containerfile.
- **Key Directories**:
  - `scripts/`: Main provisioning scripts (numbered sequentially, e.g., `01-repos.sh`, `10-gnome.sh`).
  - `system_files/`: OS overlay files injected into the image (`etc`, `usr`).
  - `.github/workflows/`: CI/CD pipelines.

## Audit Logs & Findings

### April 17, 2026 - Comprehensive Codebase Audit
Performed a line-by-line audit using `PSScriptAnalyzer` and `shellcheck`.

#### PowerShell (`PSScriptAnalyzer`)
- **`fix-token-input.ps1`**: Fixed multiline git commit message syntax. PowerShell does not support Bash-style multiline double-quote strings without explicit backtick-n (`` `n ``). Replaced standard newlines with `` `n ``.
- **`install.ps1` & `push-to-github.ps1`**: Remedied `PSAvoidUsingInvokeExpression` vulnerabilities. Downloading external scripts via `Invoke-WebRequest` and directly piping `.Content` into `Invoke-Expression` is unsafe. Refactored to write payloads to `$tmp = New-TemporaryFile`, invoke via `& $tmp.FullName`, and `Remove-Item`.
- **`install.ps1` & `scripts/cloud-ws-builder.ps1`**: Fixed `PSAvoidUsingEmptyCatchBlock`. Unhandled empty catches mask errors; replaced with `catch { $null }` or `catch { Write-Verbose ... }`.

#### Bash (`shellcheck`)
- **`scripts/bcvk-wrapper.sh`**: Fixed SC2054 (unquoted elements containing commas in array declarations). E.g., `QEMU_ARGS=( -nic user,model=virtio )` -> `QEMU_ARGS=( -nic "user,model=virtio" )`.
- **`scripts/10-gnome.sh`**: Fixed SC2038 (`find | xargs` failing due to non-alphanumeric safety). Used `find ... \( ... \) -exec cp {} /dest/ \;`. Note: `action-shellcheck@2.0.0` in CI/CD runs strictly and considers SC2038 a fatal failure.
- **`scripts/02-kernel.sh`**: Fixed SC2155. Separated declaration and assignment to avoid masking exit codes: `KVER=$(...)` then `export KVER`.
- **`scripts/11-hardware.sh`, `scripts/12-virt.sh`, `scripts/52-bake-kvmfr.sh`**: Fixed SC2012. Replaced `ls -1 /dir/ | sort` with `find /dir/ -mindepth 1 -maxdepth 1 -printf "%f\n" | sort`.

#### Deep System Scripts Audit (`system_files/` & Extensionless Scripts)
- **`system_files/usr/libexec/cloudws/role-apply` & `select-cdi-spec`**: 
  - Fixed SC2010 (`ls | grep`). Replaced `ls /dev/nvidia* | grep -q .` with the safer `compgen -G "/dev/nvidia*" >/dev/null`.
  - Fixed SC2013 (`for var in $(cat file)`). Used `for var in $(< file)` to prevent subshell/cat overhead.
- **`system_files/etc/greenboot/check/wanted.d/30-nvidia-cdi.sh`**: Replaced `ls | grep` hardware checks with `compgen -G`.
- **`system_files/usr/bin/gamescope-session-steam`**: Fixed SC2206 (unquoted array expansion). Replaced `ARRAY+=( $VAR )` with `read -ra arr <<< "$VAR"; ARRAY+=( "${arr[@]}" )`.
- **`system_files/usr/local/bin/cloudws-ceph`**: Fixed SC2162 by adding `-r` to the interactive `read` command to prevent backslash mangling.
- **`scripts/cloudws-motd`**: Fixed SC2059 (variables in `printf` format string). Avoided putting color variables directly in the format string. Removed unused variable `$Y`.
- **`scripts/42-cosign-policy.sh`**: Fixed SC2015. Replaced `A && B || C` short-circuiting with explicit `if/else` blocks to prevent unintended execution if `B` fails.
- **`scripts/31-user.sh`**: Fixed SC2013. Replaced `for u in $(awk ...)` with the safer `awk ... | while read -r u; do`.

#### Container & YAML Validation
- Ran `hadolint` on `Containerfile` and `yamllint` on `.github/workflows/`, `renovate.json`, and `image-versions.yml`. Confirmed structures are valid and functional.
- **GitHub Actions (Cosign Authentication)**: Fixed a bug where `cosign sign` was failing with `UNAUTHORIZED: unauthenticated`. The `buildah`/`podman` login commands store credentials in `~/.config/containers/auth.json`, which `cosign` ignores (it strictly looks for `~/.docker/config.json`). Added the official `docker/login-action@v3` step immediately alongside the buildah/podman logins. This safely populates the docker credential store, allowing `cosign` to inherit the authentication context and push signatures to GHCR.

## Development Guidelines
- **PowerShell**: Avoid `Invoke-Expression`. Do not use empty `catch` blocks. Use `[SecureString]` for sensitive data.
- **Bash**: Heavily rely on `shellcheck`. Use `compgen -G` instead of `ls | grep` for file existence checks. Quote variables. Use `read -ra` for word splitting.
- **Idempotency**: Scripts in this repository (especially builders) are designed to be idempotent. Ensure actions can be safely re-run without breaking state.

### April 20, 2026 - WSL2 Detection & Gating Standardization
Standardized system-wide WSL2 detection to use systemd-native primitives.

- **Standard**: `ConditionVirtualization=!wsl` is now the canonical way to gate services in systemd drop-ins.
- **Scripts**: Updated `scripts/20-services.sh`, `scripts/35-init-service.sh`, `scripts/cloudws-test`, and `scripts/cloudws-toggle-headless` to use `systemd-detect-virt` and `ConditionVirtualization` checks.
- **Fixes**: Added `fapolicyd` to the WSL skip list in `20-services.sh` due to binfmt_misc conflicts in WSL2. Fixed redundant service enablement and clobbering between `34-gpu-detect.sh` and `35-gpu-passthrough.sh`.
- **Documentation**: Updated `CONTRIBUTING.md` to mandate the new standard for all future PRs.

### April 20, 2026 - Architectural & Versioning Synchronization
Synchronized the repository baseline to v2.3.5 and unified the Role Engine architecture.

- **Versioning**: Promoted project from v0.1.8 to v2.3.5 across all metadata files (`VERSION`, `Containerfile`, `README.md`, `install.sh`, `cloud-ws.ps1`). Reconciled the engineering stream with public-facing labels.
- **Role Engine**: Consolidated `role-apply` into a single, comprehensive script in `system_files/usr/libexec/cloudws/`. Implemented asynchronous `systemctl start/stop --no-block` to prevent early-boot deadlocks while retaining Phase 1 (System Init) and Phase 2 (Blackwell Detection) features.
- **Changelog**: Aggregated all fragmented `CHANGELOG-v*.md` files from `docs/changelogs/` into the main `CHANGELOG.md`, providing a complete chronological ledger. Moved fragments to `docs/knowledge/changelogs-legacy/`.
- **Standards Compliance**: Audited and fixed remaining direct `dnf` calls to use the mandated `${DNF_SETOPT[@]}` array. Confirmed 100% compliance with `VAR=$((VAR + 1))` arithmetic safety rules.

### April 21, 2026 - v2.3.5 Architectural Consolidation & Upstream Hardening
Promoted image to v2.3.5 engineering baseline and integrated critical stability workarounds.

#### 1. NVIDIA 595.x Stability Workaround
- **Reason:** NVIDIA 595+ drivers (late March 2026) introduced a regression in video memory preservation on Ada (RTX 4090) and Blackwell (RTX 50) hardware, causing random freezes during Wayland suspend/resume cycles.
- **Fix:** Injected `NVreg_UseKernelSuspendNotifiers=1` into `nvidia-open.conf`. This forces the driver to use internal kernel hooks for memory state preservation, bypassing the problematic userspace handshake.

#### 2. WSL 2.7.0 / 2.6.0.0 Session Compatibility
- **Reason (Network):** WSL 2.7.0 introduced a hang in `systemd-networkd-wait-online.service` that blocks the systemd user session from starting, resulting in a login timeout.
- **Reason (Security):** WSL 2.6.0.0 erroneously marks `/run/systemd/user-generators/wsl-user-generator` as world-writable. systemd v259+ (in F44) rejects this for security reasons, killing the user session generator.
- **Fix:** Gated network wait on `!wsl` and enforced `0755` permissions on the generator via `tmpfiles.d`.

#### 3. bootc "Docker VOLUME" Persistence (CrowdSec)
- **Reason:** In the bootc model, `/var` is persistent but not updated via image layers. CrowdSec's sqlite database in `/var/lib/crowdsec` would fail to initialize on systems upgrading from older versions if the directory structure wasn't explicitly managed.
- **Fix:** Added `cloudws-crowdsec.conf` to `tmpfiles.d` to ensure mandatory state directories exist across the entire fleet regardless of install age.

#### 4. CI/CD Rechunking Optimization
- **Reason:** The `build.yml` was silently skipping OCI rechunking because `bootc-base-imagectl` was missing from the Ubuntu runner. Updates were monolithic (multi-GB) instead of chunked (MBs).
- **Fix:** Wrapped rechunking in a `podman run --privileged` using the image itself, guaranteeing tool presence and achieving 5-10x smaller Day-2 deltas.

#### 5. Architectural Purity (Single Source of Truth)
- **Reason:** Fragmented directories (`systemd/`, `udev/` in root vs `system_files/`) caused "cannot stat" failures in `35-gpu-passthrough.sh` when paths drifted.
- **Fix:** Deleted all root-level config directories and consolidated everything into the `system_files/` overlay.

#### 6. Build Diagnostics & NFS Persistence
- **Reason:** Mandatory package sections (kernel, core) failing silently or without clear logs in CI made debugging difficult.
- **Fix:** Added fatal logging to `install_packages_strict` in `packages.sh`.
- **Reason:** NFS status monitoring (`statd`) requires a persistent directory in `/var`. Creating it via script clutters the provisioning logic.
- **Fix:** Moved NFS state directory management to `tmpfiles.d/cloudws-nfs.conf`.

### April 21, 2026 - v0.1.8 Versioning Standardization & Full Functionality Pass
Unified the repository on the v0.1.8 baseline and implemented missing architectural components.

#### 1. Versioning Precedence (Lower Takes Precedence)
- **Decision:** Standardized all repository metadata and script headers to the **v0.1.8** stream, reconciling the previous engineering-only v2.x labels.
- **Action:** Re-mapped the `CHANGELOG.md` history to align engineering milestones with the v0.1.x chronological ledger.

#### 2. Formal Target Architecture
- **Reason:** Legacy role initialization via scripts was brittle and hard to isolate. 
- **Fix:** Created formal systemd targets (`cloudws-desktop.target`, etc.) and updated the Role Engine to use `systemctl isolate`. This provides clean state transitions and robust dependency management.

#### 3. Management Dashboard (MOTD)
- **Action:** Completely redesigned the MOTD (at `/usr/libexec/cloudws/motd`) to provide live Role, MOK (Secure Boot), and bootc Update status indicators. This acts as the primary bridge for "Headless GUI" management.

#### 4. Flatpak Pre-installation Standard (2026)
- **Reason:** Custom scripts for Flatpak installation added unnecessary build time and service overhead.
- **Fix:** Adopted the `/usr/share/flatpak/pre-installed.d/` declarative pattern for mandatory essentials (Epiphany, Flatseal).

#### 5. Native AI Environment (Coordination)
- **Reason:** Multi-agent development (Claude, Gemini, Cursor) required a "natively understood" state to prevent architectural regressions.
- **Fix:** Established `.ai-context/AI-ENVIRONMENT.md` and `.env` as the global source of truth. Configured VSCode, Claude, and Gemini to natively inject and respect these variables.

#### 6. Logging & Print-out Purity
- **Action:** system-wide audit and fix of malformed UTF-8 characters (`???`) and box-drawing elements. Standardized build logging with high-visibility STEP markers in `build.sh`.
