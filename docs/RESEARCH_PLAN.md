# Research and Remediation Plan for Missing Components and Issues

### Overview
This document outlines the comprehensive research and remediation plan for the 13 missing components and architectural discrepancies identified during the project audit.

---

## Phases

### Phase 1: Identification
- **Milestone:** Complete identification of all missing components.
- **Deliverables:** Detailed list of missing components (Completed).
- **Research Tasks:**  
  1. Review existing documentation and package manifests.  
  2. Audit system scripts and container definitions.  

### Phase 2: Research
- **Milestone:** Conduct research for each missing component.
- **Deliverables:** Research findings documents for each component.
- **Research Tasks:**  
  1. Identify upstream Fedora/bootc references.  
  2. Analyze solutions from Universal Blue and similar projects.

### Phase 3: Remediation
- **Milestone:** Remediate issues based on research findings.
- **Deliverables:** Implemented solutions for all components.
- **Research Tasks:**  
  1. Develop initial script/manifest solutions.  
  2. Test and validate across hardware targets.

---

## Kanban Board

| Task / Component | Status | Milestone | Deliverables | Upstream References |
|------------------|--------|-----------|--------------|---------------------|
| **1. Ceph & K3s Storage** | Done | Remediation | Remove 'planned' tag from docs | N/A |
| **2. K3s SELinux** | To Do | Research | Evaluate COPR/alternatives for F44 | CentOS/RHEL k3s-selinux |
| **3. Pacemaker HA VM Gating** | To Do | Research | Evaluate HA stack for VMs | Fedora Pacemaker Docs |
| **4. ComposeFS Verity Bug** | In Progress | Research | Monitor systemd-remount-fs interop | systemd/composefs issues |
| **5. Unified Kernel Image (UKI)** | To Do | Research | Implement composefs+UKI chain | bootc UKI roadmap |
| **6. FreeIPA/SSSD Automation** | To Do | Research | Evaluate zero-touch enrollment | FreeIPA Client Docs |
| **7. Fapolicyd Alternatives** | To Do | Research | Find lighter app whitelisting | Fedora Security |
| **8. Cosign Verification** | To Do | Research | Package via COPR/Go for F44 | sigstore/cosign |
| **9. Podman-Docker Symlink** | To Do | Research | Resolve moby-engine conflict | ublue-os/ucore |
| **10. Intel Compute Stack** | In Progress | Research | Monitor level-zero/libproc2 | Fedora/Intel Compute |
| **11. Utility Packages Addition** | Done | Remediation | Add ntfs-3g, strace, lsof, etc. | PACKAGES-AUDIT.md |
| **12. NVIDIA Waydroid 3D** | To Do | Research | Evaluate hardware acceleration | Waydroid/NVIDIA docs |
| **13. RTX 50-Series VFIO Bug** | In Progress | Research | Track upstream reset bug fixes | VFIO / NVIDIA Open kmods |

---

### Conclusion
This plan aims to trace and rectify all missing components and issues affecting the CloudWS-bootc project. Tracking progress through the Kanban matrix will ensure transparency and accountability throughout the process.