# MiOS Historical Knowledge Compressed - v0.1.3

**Generated:** 2026-04-28
**Source:** Memory artifacts, journals, audit reports, changelogs, research plans
**Purpose:** Condensed historical context for AI knowledge base integration
**Format:** Chronological + categorical compression

---

## [MEM] Episodic Memory Summary

### Storage Architecture

**Primary Store:** `var/lib/mios/memory/journal/v1.jsonl` (JSONL format, API-native)
**Interface:** `JOURNAL.md` (human-readable markdown)
**Sync Tool:** `tools/journal-sync.py` (bi-directional)

### Key Historical Events (2026-04-27 to 2026-04-28)

**1. Knowledge Mapping & Flattening** (2026-04-27 05:20 UTC)
- Created Technology Patterns map (specs/engineering/2026-04-27-Artifact-ENG-005-Technology-Patterns.md)
- Completed FOSS AI compliance structuring

**2. GitHub Actions Build Fix** (2026-04-27 04:55 UTC)
- Issue: Missing `home/` and `var/` directories in build context
- Solution: Created `.gitkeep` files in user-space subdirectories
- Result: Build context integrity restored for remote runners

**3. Structured Memory Architecture** (2026-04-27 05:40 UTC)
- Refactored journaling to API-native JSONL format
- Created migration tool (tools/journal-sync.py)
- Documented Linux-Native Memory Standards (specs/core/2026-04-27-Artifact-COR-006)
- Result: Cognitive history now structured for high-fidelity AI API ingestion (FHS compliant)

**4. Linux FS Native Implementation** (2026-04-27 18:35 UTC)
- Unified artifacts, logs, snapshots, wiki into single FHS 3.0 structure
- Achieved 99.95% compression (928 MB → 509 KB XZ)
- Implemented automatic Wiki sync
- Created comprehensive FOSS AI integration
- Ready commits: Main (2), Bootstrap (2), Wiki (1)

**5. Stability Checks & WSL2 Hardening** (2026-04-27 21:20 UTC)
- Fixed systemd ordering cycle (mios-role.service moved to multi-user.target)
- Implemented WSL2 journald stabilization (Storage=volatile)
- Added SSH initialization via tmpfiles.d
- Migrated Flatpak env to /usr/lib/mios/env.d/

**6. Locale & WSL2 Pathing Fixes** (2026-04-27 22:00 UTC)
- Resolved UTF-8 locale detection issues
- Fixed dbus-daemon-wsl execution errors
- Gated resource-heavy services for WSL2

**7. CLI Refinement & CI/CD Optimization** (2026-04-27 23:00 UTC)
- Unified CLI syntax (hyphenated + underscored commands)
- Implemented "Mode 0" bootstrap (curl | bash)
- Fixed CI/CD "No space left on device" failures
- Relocated management binaries to /usr/libexec/mios/

**8. Build Orchestrator Stabilization** (2026-04-28 01:12 UTC)
- Resolved exit code 2 failures in automation/build.sh
- Fixed pipefail issues with ls/glob operations
- Refactored to robust array-based file counting
- Achieved 100% success rate for build summary reporting

**9. Emoji Removal & Terminal Compatibility** (2026-04-28 01:24 UTC)
- Executed global Unicode-to-ASCII replacement (tools/remove-emojis.py)
- Implemented ASCII progress bars for all terminals
- Added MIOS_LIVE_BUILD indicator support

**10. Global Variable Registry** (2026-04-28 01:59 UTC)
- Created config/registry.toml as Single Source of Truth
- Implemented tools/propagate.py for automated synchronization
- Added @track anchors across codebase
- Optimized with 1MB file limit and pre-filtering

---

## [ADT] Research Audit Findings (April 2026)

### Source: 2026-04-26-Artifact-ADT-002-Research-April2026.md (1604 lines)

### bootc Upstream (bootc-dev/bootc v1.15.x)

**Repo Status:**
- Moved from containers/bootc to bootc-dev/bootc
- CNCF Sandbox project (Jan 2025)
- Current stable: v1.15.1 (April 14, 2026)

**Key Features:**
- `bootc upgrade --download-only` - Staged updates
- `bootc completion bash` - Shell completions
- `bootc status --booted` - Boot verification
- `bootc rollback` - NOT supported on composefs-native
- `--karg-delete` - Remove kernel args (v1.15+)

**Container Lint Rules:**
1. kargs.d syntax validation (flat arrays only)
2. Single kernel per image
3. No files in /usr/etc (forbidden)
4. tmpfiles.d entries for /var directories
5. UTF-8 filename validation
6. Stale logfile detection
7. match-architectures validation (Rust arch names)

**Filesystem Semantics:**
- `/usr` - Immutable, composefs-covered, read-only
- `/etc` - 3-way merge on upgrades
- `/var` - Persistent state, excluded from updates
- `/run` - API filesystem (never ship content)
- `/usr/local` - Mutable by default

**composefs Requirements:**
- Requires ext4 or btrfs (NOT XFS)
- fs-verity support mandatory
- OSTree backend (not composefs-native) for rollback capability

### Universal Blue / ucore-hci

**NVIDIA:**
- Now on NVIDIA v595+ open modules
- RTX 50xx requires open modules exclusively
- CDI default mode (nvidia-container-toolkit v1.16+)
- DO NOT use v1.15 (CDI regression)

**Secure Boot:**
- Microsoft UEFI CA 2011 expires June 26, 2026
- Existing enrollments unaffected
- MOK keys must be 2048-bit RSA (not 4096-bit)

**Service Conflicts:**
- cockpit.socket race with libvirtd.socket
- libvirtd 45s shutdown timeout too short (set to 120s)
- ublue-os/cayo - composefs-native HCI successor (monitor)

**Cosign CRITICAL:**
- Stay on cosign v2.x (NOT v3)
- v3 --new-bundle-format BREAKS rpm-ostree/bootc
- Always pass --new-bundle-format=false

### Fedora bootc / FCOS / OCI Transition

**Fedora 44 (April 28, 2026):**
- Konflux becomes build pipeline for bootc artifacts
- Digest pins may see more frequent churn
- greenboot-rs approved for F43+ (replaces shell-based)

**Soft Reboot:**
- `systemctl soft-reboot` (kexec-based)
- Significantly reduces downtime
- Available in F44+ (not yet in F42/F43)

### Podman Quadlet / systemd Integration

**Logically Bound Images:**
- Declared in /usr/lib/bootc/bound-images.d/
- Pre-fetched by bootc on upgrade/install
- Only downloaded when app image changes
- Candidates: crowdsec-dashboard, guacamole, monitoring

### WSL2 / systemd Integration

**Known Issues:**
- systemd-networkd-wait-online causes login timeouts (gate with !wsl)
- wsl-user-generator permissions (enforce 0755 via tmpfiles.d)
- journald crashes without Storage=volatile
- dbus-daemon path must be /bin/dbus-daemon

### Security / SELinux / CrowdSec

**SELinux:**
- Never use semodule -i at build time
- Stage in /usr/share/selinux/packages/
- Load asynchronously via mios-selinux-init.service

**fapolicyd:**
- Application whitelisting
- Trust database in /etc/fapolicyd/

**CrowdSec:**
- IPS/IDS integration
- Dashboard via Quadlet container

---

## [MEM] Research Plans & Strategies

### Source: 2026-04-26-Artifact-MEM-002-Research-Plan.md (251 lines)

### bootc Implementation Actions

**Commands:**
- Add `bootc completion bash` to Containerfile
- Document `bootc usroverlay --readonly` in DIAGNOSTICS.md
- Use `bootc status --booted` in greenboot checks

**kargs.d:**
- Fix match-architectures in 30-security.toml (use x86_64, not amd64)
- Maintain flat kargs arrays (no [kargs] headers)

**composefs:**
- Verify ext4 rootfs (already correct in bib-configs)
- Stay on OSTree backend (not composefs-native)
- Ensure readonly=true in prepare-root.conf

**Container Lint:**
- Verify all /var dirs have tmpfiles.d entries
- No files in /usr/etc
- Remove stale logs in 99-cleanup.sh

### NVIDIA Actions

- Inherit v595+ open modules from ucore-hci base
- Handle RTX 50xx in 34-gpu-detect.sh
- Maintain nvidia-cdi-refresh.path/.service for CDI
- DO NOT add NVreg_UseKernelSuspendNotifiers=1 unconditionally

### Secure Boot Actions

- Document Microsoft UEFI CA 2011 expiration
- Ensure MOK keys are 2048-bit RSA
- Update edk2-ovmf on VM hosts

### ucore Notable Defaults

- Add After=libvirtd.socket to cockpit.socket.d/10-mios.conf
- Maintain TimeoutStopSec=120 for libvirtd.service
- Monitor ublue-os/cayo for future base migration

### Cosign Critical

- Pin cosign v2.x in build.yml
- Always use --new-bundle-format=false
- Never upgrade to cosign v3 (breaks bootc)

---

## [MEM] Work Plans

### Source: 2026-04-26-Artifact-MEM-004-Work-Plan.md (164 lines)

### Immediate Priorities

1. **FHS 3.0 Compliance** - 100% verified
2. **bootc Container Lint** - All checks passing
3. **WSL2 Hardening** - Completed
4. **FOSS AI Integration** - Completed
5. **Global Variable Registry** - Implemented

### In-Progress Tasks

1. **MiOS-NXT Planning**
   - Hummingbird (zero-CVE minimal base)
   - SBOM generation (CycloneDX + SPDX)
   - ARM64 support (Raspberry Pi 5, AWS Graviton)
   - Minimal variants (Desktop, Core, Edge)

2. **Build Pipeline**
   - Rechunk optimization (5-10x smaller deltas)
   - Digest pinning with Renovate
   - Automatic Wiki sync
   - Bootstrap integration

3. **Security Hardening**
   - SELinux policies
   - fapolicyd whitelisting
   - CrowdSec IPS
   - composefs + fs-verity

### Future Roadmap

**Q2 2026:**
- Fedora 44 migration
- greenboot-rs integration
- Konflux build pipeline transition

**Q3-Q4 2026:**
- MiOS-NXT development
- Hummingbird base migration
- ARM64 cross-arch builds
- SBOM compliance (EU CRA)

**Q1-Q2 2027:**
- Minimal variants release
- Production-grade monitoring
- Edge/IoT variant (<200MB)

---

## [CHL] Changelog Summary

### Source: 2026-04-26-Artifact-CHL-003-v0.1.1.md (149 lines)

### v0.1.1 Release (2026-04-26)

**Major Changes:**
1. Fedora Rawhide + ucore-hci base
2. Pre-signed NVIDIA kmods (kmod-nvidia-open)
3. FHS 3.0 compliance
4. USR-OVER-ETC architecture
5. tmpfiles.d mandatory for /var directories

**Build System:**
- 54 numbered automation scripts
- Master orchestrator (automation/build.sh)
- Unified logging with state tracking
- Status card rendering

**FOSS AI Integration:**
- Knowledge graph (mios-knowledge-graph.json)
- RAG manifest (rag-manifest.yaml)
- AI context hub (ai-context.json)
- Function calling interface (.well-known/ai-tools.json)

**Compression:**
- 99.95% compression (928 MB → 509 KB XZ)
- Complete RAG packages
- Bootstrap integration

**Security:**
- SELinux enforcing
- fapolicyd whitelisting
- CrowdSec IPS
- composefs + fs-verity
- cosign image signing

**Desktop:**
- GNOME 47+ (Wayland native)
- Flatpak sandboxing
- XDG standards compliance

**Virtualization:**
- libvirt + QEMU/KVM
- VFIO GPU passthrough
- Looking Glass integration
- Waydroid (Android containers)

---

## [TECH] Technology Evolution

### bootc Versions Tracked

- v1.9.0 (2024) - composefs/image sealing
- v1.11.0 (2025) - kargs.d support
- v1.12.0 (2025) - --download-only flag
- v1.14.0 (2026) - Pre-flight disk checks
- v1.15.1 (2026) - Current stable (Intel VROC fix)

### NVIDIA Driver Progression

- MiOS-1: akmod NVIDIA drivers (manual build)
- MiOS-2 v0.1.x: Pre-signed kmods from ucore-hci
- Current: v595+ open modules
- RTX 50xx: Open modules mandatory

### Fedora Releases

- F40 (2024) - Initial bootc support
- F41 (2025) - bootc stabilization
- F42 (2025-2026) - Current stable
- F43 (Sept 2025) - greenboot-rs approved
- F44 (April 28, 2026) - Konflux build pipeline

### Container Runtime

- Podman 4.x (2024) - Rootless support
- Podman 5.x (2025-2026) - Current (CDI native)
- Quadlet - systemd-native containers
- Logically bound images - bootc managed

---

## [PATTERN] Development Patterns Emerged

### 1. Immutable Laws Enforcement

Evolution from ad-hoc to systematic:
- Started: Individual script modifications
- Evolved: 5 Golden Laws documented
- Current: Automated lint enforcement

### 2. Variable Management

Evolution from scattered to centralized:
- Started: Hardcoded values in multiple files
- Evolved: .env files with manual sync
- Current: config/registry.toml with @track: propagation

### 3. AI Integration

Evolution from proprietary to FOSS:
- Started: Vendor-specific patterns
- Evolved: API-agnostic interfaces
- Current: Full FOSS AI stack (Ollama, llama.cpp, LocalAI, vLLM)

### 4. Memory Architecture

Evolution from flat to structured:
- Started: Markdown journal only
- Evolved: Dual format (MD + some JSON)
- Current: JSONL primary + MD interface + sync tool

### 5. Artifact Management

Evolution from manual to automated:
- Started: Manual archiving
- Evolved: Compression scripts
- Current: 99.95% compression + automatic Wiki sync + Bootstrap integration

### 6. Build Pipeline

Evolution from monolithic to modular:
- Started: Single build script
- Evolved: Numbered scripts
- Current: Master orchestrator + 54 specialized scripts + state tracking

---

## [KEY] Critical Decision Points (Historical)

### Decision 1: FHS 3.0 Compliance (April 2026)

**Context:** Mixed directory structures across the codebase
**Decision:** Full FHS 3.0 compliance with USR-OVER-ETC
**Impact:** 100% compliant, passes bootc container lint
**Rationale:** Linux-native deployment, predictable AI discovery

### Decision 2: OSTree vs composefs-native (April 2026)

**Context:** composefs-native backend available but immature
**Decision:** Stay on OSTree backend with composefs verification
**Impact:** Rollback capability preserved
**Rationale:** composefs-native lacks rollback as of v1.15.x

### Decision 3: FOSS AI API Agnostic (April 2027)

**Context:** Initial vendor-specific integrations
**Decision:** Full FOSS stack, vendor-neutral patterns
**Impact:** Compatible with Ollama, llama.cpp, LocalAI, vLLM
**Rationale:** Open-source principles, no vendor lock-in

### Decision 4: XZ Primary Compression (April 2026)

**Context:** GZ compression yielding 814 KB packages
**Decision:** Switch to XZ (LZMA2) compression
**Impact:** 509 KB packages (37% better than GZ)
**Rationale:** Maximum space efficiency

### Decision 5: Global Variable Registry (April 2026)

**Context:** Version/image references scattered across files
**Decision:** Centralized config/registry.toml with @track: propagation
**Impact:** Automated synchronization, no manual updates
**Rationale:** Single source of truth, reduced maintenance

### Decision 6: Wiki as Live Documentation (April 2026)

**Context:** Static docs lag behind development
**Decision:** Automatic Wiki sync on every build
**Impact:** Current docs always available, AI-discoverable
**Rationale:** Live documentation beats static snapshots

### Decision 7: Cosign v2.x Pin (April 2026)

**Context:** Cosign v3 released with new bundle format
**Decision:** Explicitly stay on v2.x, never upgrade to v3
**Impact:** Builds continue to work
**Rationale:** v3 --new-bundle-format breaks bootc (upstream bug)

### Decision 8: Emoji Removal (April 2026)

**Context:** Terminal rendering issues on Windows
**Decision:** Global Unicode-to-ASCII replacement
**Impact:** Clean rendering on all terminals
**Rationale:** Platform compatibility, build log clarity

---

## [STAT] Historical Metrics

### Development Activity (April 2026)

- **Commits:** 100+ across main, bootstrap, wiki
- **Files Modified:** 200+ files
- **Lines Changed:** 10,000+ lines
- **Documentation:** 2,457 lines of historical artifacts
- **Automation Scripts:** 54 numbered scripts
- **AI Integration Files:** 7 specification documents

### Knowledge Base Growth

- **Memory Entries:** 10+ episodic events (JSONL)
- **Research Findings:** 1,604 lines (April 2026 audit)
- **Work Plans:** 164 lines
- **Research Strategies:** 92 lines
- **Changelog:** 149 lines

### Artifact Statistics

- **Compression Achieved:** 99.95% (928 MB → 509 KB)
- **Knowledge Graph:** 105 lines JSON
- **RAG Manifest:** 108 lines YAML
- **Script Inventory:** 234 lines JSON
- **Complete RAG Package:** 722 files

---

## [LEARN] Lessons Learned

### 1. Pipefail Pitfalls

**Context:** Build failure with exit code 2
**Issue:** `set -euo pipefail` + `ls` with non-matching globs
**Lesson:** Use array-based file counting in strict bash
**Solution:** Refactored to safe array assignment + size checking

### 2. Unicode in Build Logs

**Context:** Terminal rendering issues on Windows
**Issue:** Emojis/box-drawing characters garbled
**Lesson:** ASCII-only for maximum compatibility
**Solution:** Created 167-emoji translation dictionary

### 3. Multi-Level Prompts

**Context:** Redundant user prompts in Windows build
**Issue:** bootstrap → install → build wrapper chain
**Lesson:** Strict env-var passing required for efficiency
**Solution:** Inherited MIOS_* variables through chain

### 4. Secret Masking

**Context:** Passwords visible in build logs
**Issue:** Regex-based masking requires special char escaping
**Lesson:** PowerShell $ in passwords needs careful handling
**Solution:** Format-Masked engine with automatic registration

### 5. composefs-native Immaturity

**Context:** composefs-native backend available
**Issue:** Missing rollback, --download-only, /etc merge
**Lesson:** Feature parity not achieved as of v1.15.x
**Solution:** Stay on OSTree backend for production

### 6. Cosign v3 Breaking Change

**Context:** Cosign v3 released with new bundle format
**Issue:** --new-bundle-format breaks rpm-ostree/bootc
**Lesson:** Test major version upgrades in isolation
**Solution:** Explicit pin to v2.x, never auto-upgrade

### 7. WSL2 systemd Quirks

**Context:** Boot failures in WSL2
**Issue:** journald crashes, networkd timeouts, dbus paths
**Lesson:** WSL2 requires specific hardening
**Solution:** Storage=volatile, !wsl gates, /bin/dbus-daemon

### 8. Global Variable Sprawl

**Context:** Image/version references in 20+ files
**Issue:** Manual updates error-prone, inconsistent
**Lesson:** Centralization beats distribution for mutable values
**Solution:** config/registry.toml + @track: automated propagation

---

## [FUTURE] Roadmap Integration

### Near-Term (Q2 2026)

Based on historical trends and current momentum:

1. **Fedora 44 Migration** - Konflux build pipeline
2. **greenboot-rs Integration** - Replace shell-based
3. **ublue-os/cayo Evaluation** - composefs-native HCI successor
4. **SBOM Automation** - 90-generate-sbom.sh enhancement

### Mid-Term (Q3-Q4 2026)

Projected from research plans:

1. **MiOS-NXT Development** - Hummingbird base
2. **ARM64 Support** - Raspberry Pi 5, AWS Graviton
3. **Minimal Variants** - Core (<500MB), Edge (<200MB)
4. **EU CRA Compliance** - SBOM (CycloneDX + SPDX)

### Long-Term (Q1-Q2 2027)

Strategic goals:

1. **Production Variants** - Desktop, Core, Edge
2. **Enterprise Features** - Monitoring, log aggregation
3. **Multi-Arch Builds** - x86_64, aarch64
4. **IoT/Embedded** - <200MB footprint

---

## [REF] Cross-References

### Primary Knowledge Files

- **AI-KNOWLEDGE-CONSOLIDATED.md** - Current AI integration reference
- **INDEX.md** - Architectural laws and directory map
- **SELF-BUILD.md** - Build modes and workflows
- **USER-SPACE-GUIDE.md** - XDG configuration patterns
- **DEPLOY.md** - Linux FS native deployment

### Historical Artifacts

- **specs/memory/** - 4 memory artifacts (573 lines total)
- **specs/audit/** - 2 audit reports (1,735 lines total)
- **specs/changelogs/** - 1 changelog (149 lines)
- **JOURNAL.md** - Human-readable episodic memory
- **var/lib/mios/memory/journal/v1.jsonl** - Machine-readable JSONL

### AI Integration

- **artifacts/ai-rag/mios-knowledge-graph.json** - Current state
- **artifacts/ai-rag/rag-manifest.yaml** - FOSS AI config
- **artifacts/ai-rag/script-inventory.json** - Automation catalog
- **ai-context.json** - Manifest pointers
- **.well-known/ai-tools.json** - Function calling interface

### Build System

- **Containerfile** - OCI build definition (2-stage)
- **automation/build.sh** - Master orchestrator
- **Justfile** - Build targets and workflows
- **config/registry.toml** - Variable SSOT
- **tools/propagate.py** - Variable synchronization

---

**Compression Summary:**
- Original historical artifacts: 2,457 lines
- Compressed knowledge base: This document
- Retention: 100% of critical knowledge + patterns + decisions
- Format: Chronological + categorical for AI ingestion

**Generated:** 2026-04-28
**Version:** MiOS v0.1.3
**License:** Personal Property - MiOS-DEV
**Repository:** https://github.com/Kabuki94/MiOS-bootstrap
