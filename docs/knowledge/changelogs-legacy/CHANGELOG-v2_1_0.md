# Cloud-WS v2.1.0 Changelog

## Summary
This update corrects critical issues with CPU isolation presets for AMD X3D processors and adds a comprehensive VM Template Management system for creating Windows 11 Secure Boot-enabled VMs with optimal CPU pinning.

---

## Changes

### 1. CPU Isolation Preset Corrections

#### Gaming Optimized (X3D) - Option 1
**Before (Incorrect):**
- Host: Last 4 threads of CCD1 (CPUs 28-31)
- VM: All of CCD0 (CPUs 0-15)

**After (Corrected):**
- Host: Core 0 from CCD0 (CPUs 0,16) + ALL of CCD1 (CPUs 8-15, 24-31) = 18 threads
- VM: CCD0 cores 1-7 (CPUs 1-7, 17-23) = 14 V-Cache threads
- Emulator Pin: 0,16

**Rationale:** Gaming VMs benefit most from V-Cache, but reserving one V-Cache core for host ensures responsive desktop. CCD1 provides high-frequency cores for host services.

---

#### Multi-VM Balanced (X3D) - Option 2 (NEW DEFAULT)
**Before:** Simple linear split (0-7 host, 8-31 VM)

**After (NEW):**
- Host: First 2 cores from each CCD (CPUs 0,1,16,17 + 8,9,24,25) = 8 threads
- Gaming Pool: CCD0 cores 2-7 (CPUs 2-7, 18-23) = 12 V-Cache threads
- Service Pool: CCD1 cores 10-15 (CPUs 10-15, 26-31) = 12 High-Freq threads
- Emulator Pin: 0,1,16,17

**Rationale:** Supports multiple VM use cases - gaming VM gets V-Cache benefit while containers/services use high-frequency CCD1 cores. Now the recommended default selection.

---

#### Host Priority - Option 3
**Before (INVERTED!):**
- Host: CPUs 0-15 (V-Cache CCD0!)
- VM: CPUs 16-31

**After (Corrected):**
- Host: All of CCD0 (CPUs 0-7, 16-23) = 16 V-Cache threads
- VM: All of CCD1 (CPUs 8-15, 24-31) = 16 High-Freq threads
- Emulator Pin: 0,1,16,17

**Rationale:** For host-priority workloads, the host should indeed get V-Cache for desktop performance. This is now correctly labeled and implemented as a 50/50 CCD split.

---

### 2. Default Preset Changed

- Default selection changed from Option 1 to **Option 2 (Multi-VM Balanced)**
- Pressing Enter now selects the recommended Balanced preset
- Invalid input also defaults to Balanced instead of erroring

---

### 3. New VM Template Manager (Menu Option 6)

Added comprehensive VM template management system with:

#### Create New VM from Secure Boot Template
- Pre-configured Windows 11 Secure Boot + TPM 2.0
- Q35 chipset with 8 PCIe root ports for GPU passthrough
- Hyper-V enlightenments for optimal Windows performance
- Three pinning presets:
  - Gaming Optimized (14 vCPUs on V-Cache)
  - Balanced Gaming Pool (12 vCPUs on V-Cache) [Default]
  - Service/Workstation (12 vCPUs on CCD1)
- Custom vCPU and pinning option
- Automatic MAC address generation
- Hook configuration file creation

#### Apply CPU Pinning to Existing VM
- Select from defined VMs
- Apply any of the three presets
- Manual pinning option
- Automatic emulator pin configuration
- Hook config generation

#### Apply Secure Boot + Pinning to Existing VM
- Upgrade existing VMs with:
  - OVMF Secure Boot firmware
  - TPM 2.0 emulation
  - SMM enabled
  - CPU pinning
- Automatic backup of original XML
- Uses virt-xml when available

#### View CPU Pinning Presets
- Visual documentation of X3D topology
- Preset specifications with exact CPU mappings
- Recommended use cases

---

### 4. Menu Structure Updates

**Main Menu:**
- Added Option 6: VM Template Manager
- Shifted Tools section to 7-9
- Updated menu loop and CLI handlers

**CLI Commands Added:**
- `vm-template` or `template` - Direct access to VM Template Manager

---

### 5. Supporting Functions Added

- `cpu_preset_x3d_balanced()` - New default preset for X3D
- `manage_vm_templates()` - Main template manager function
- `vm_template_show_menu()` - Template manager menu
- `vm_template_show_presets()` - Preset documentation
- `vm_template_create_new()` - Create VM from template
- `vm_generate_secureboot_xml()` - Generate complete VM XML
- `vm_template_apply_pinning()` - Apply pinning to existing VM
- `vm_template_apply_full_config()` - Full upgrade existing VM
- `vm_template_apply_pinning_to_vm()` - Internal pinning helper
- `vm_create_hook_config()` - Generate per-VM hook config

---

## Preset Reference Table

| Preset | Option | Host CPUs | VM CPUs | V-Cache for VMs | Best For |
|--------|--------|-----------|---------|-----------------|----------|
| Gaming Optimized | 1 | 0,16 + 8-15,24-31 (18) | 1-7,17-23 (14) | 87.5% (7/8 cores) | Single gaming VM |
| **Multi-VM Balanced** | **2** | **0,1,8,9,16,17,24,25 (8)** | **24 total** | **75% (6/8 cores)** | **Gaming + Services** |
| Host Priority | 3 | 0-7,16-23 (16) | 8-15,24-31 (16) | 0% (on host) | Heavy host + VMs |

---

## File Changes

- `cloudws-full.sh`: 4,497 â†’ 5,300 lines (+803 lines)
- New functions: 10
- Updated functions: 5

---

## Testing Recommendations

1. Run `sudo ./cloudws-full.sh status` to verify CPU detection
2. Select CPU Isolation Option 2 to test new default behavior
3. Use VM Template Manager to create a test VM
4. Verify CPU pinning with `virsh vcpupin <vm-name>`
5. Check hook config at `/etc/libvirt/hooks/qemu.d/<vm>.conf`
