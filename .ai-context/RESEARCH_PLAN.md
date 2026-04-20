# 🔬 Codebase Audit & Research Plan — April 2026

## 1. Executive Summary
A comprehensive audit of the `CloudWS-bootc` repository was performed to identify gaps in files, implementations, and architectural consistency. While the build process is robust, several areas of technical debt, duplication, and potential runtime conflicts were identified.

## 2. Identified Gaps & Inconsistencies

### 2.1 Build Pipeline & Scripting
- **Double Execution Risk:** `scripts/build.sh` skips scripts 18-26, but `Containerfile` executes them manually. This is brittle. If a new script is added in the 20-series, it might be executed twice unless both files are updated.
- **Redundant Scripts:**
  - `scripts/41-akmods-copy.sh`: Marked as removed in `PACKAGES.md` changelog (v2.2) but still present in the repo.
  - `scripts/37-cosign-policy.sh` vs `scripts/42-cosign-policy.sh`: Duplicated logic for container policy enforcement.
- **Overlapping Initialization:** `scripts/35-init-service.sh` and `scripts/48-role-system.sh` both handle boot-time configuration. `35-init-service.sh` writes a custom `cloudws-init` binary, while `48-role-system.sh` refers to `cloudws-role.service` (which ships via `system_files`).

### 2.2 Configuration & Overlays
- **`system_files` Shadowing:** Some files in `system_files/` mirror those in `sysusers.d/`, `tmpfiles.d/`, and `kargs.d/` at the repo root.
- **WSL2 Gating:** Standardized on `ConditionVirtualization=!wsl`, but some legacy checks might remain in extensionless scripts or documentation examples.

### 2.3 Package Manifest (`docs/PACKAGES.md`)
- **F44 Incompatibilities:** Several packages (`level-zero`, `intel-gpu-tools`, `podman-docker`, `cosign`) were removed due to F44 repo missing/conflicts. Research is needed to find alternative COPRs or build-from-source paths.
- **Optional Bloat:** The `gnome-core-apps` section is fully commented out. We need to verify if users actually want some of these as defaults or if the "pure build-up" is too aggressive.

## 3. Research Agenda

### Phase 1: Consolidation & Cleanup (Immediate)
- **Goal:** Eliminate duplication and clarify script ownership.
- **Tasks:**
  - Audit `scripts/37-cosign-policy.sh` and `scripts/42-cosign-policy.sh` and merge into a single `37-cosign-policy.sh`.
  - Verify if `scripts/41-akmods-copy.sh` is truly dead and remove it.
  - Refactor `Containerfile` and `build.sh` to use a more dynamic skip list or move all scripts back into the main runner.

### Phase 2: Role System Unification
- **Goal:** Single source of truth for first-boot logic.
- **Tasks:**
  - Compare `scripts/35-init-service.sh` (writes `/usr/libexec/cloudws-init`) with the `system_files/usr/libexec/cloudws/role-apply` system.
  - Research moving all "every-boot" logic into `role-apply` and keeping `init-service` strictly for "once-ever" setup.

### Phase 3: Hardware & Upstream Gaps
- **Goal:** Resolve F44 package gaps and RTX 50-series stability.
- **Tasks:**
  - **Research:** Check `koji.fedoraproject.org` for `level-zero` and `intel-gpu-tools` status in F44.
  - **Research:** Investigate `cosign` protobuf v3 vs v2 compatibility with `rpm-ostree`.
  - **Action:** Create a verification script for RTX 50-series VFIO reset bug.

## 4. Execution Log (Tracked in ai-journal.md)
- [2026-04-20] Audit complete. Research plan drafted.
- [Next] Consolidation of cosign and akmod scripts.
