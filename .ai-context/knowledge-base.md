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
