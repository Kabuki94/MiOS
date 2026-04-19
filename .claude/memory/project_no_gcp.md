---
name: no-gcp-support
description: CloudWS-bootc does not implement Google Cloud Platform support
type: project
---

CloudWS-bootc does not target GCP. No GCE images, no Cloud Workstations, no GAR push, no GKE — none of it. Confirmed by Kabu April 2026.

**Why:** Not a target platform for this project.
**How to apply:** Reject or flag any GCP-specific deliverables (bib-configs/gcp.toml, gar-auth-refresh, Terraform for GCP, push-gar.yml, etc.) before implementing them.
