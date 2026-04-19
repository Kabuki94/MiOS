# CloudWS-bootc on GCP — Terraform

## Prerequisites

- Terraform >= 1.6 or OpenTofu >= 1.7
- A GCP project with billing enabled
- Required APIs: `compute.googleapis.com`, `artifactregistry.googleapis.com`,
  `workstations.googleapis.com`, `container.googleapis.com`, `iap.googleapis.com`,
  `iamcredentials.googleapis.com`, `storage.googleapis.com`,
  `containerscanning.googleapis.com`
- `gcloud auth application-default login` as a principal with
  `roles/owner` (or a narrower custom bundle) on the project

## Bootstrap

```bash
gcloud services enable \
  compute.googleapis.com artifactregistry.googleapis.com \
  workstations.googleapis.com container.googleapis.com \
  iap.googleapis.com iamcredentials.googleapis.com \
  storage.googleapis.com containerscanning.googleapis.com

cat > terraform.tfvars <<'EOF'
project_id     = "my-project"
region         = "us-central1"
zone           = "us-central1-a"
staging_bucket = "my-project-cloudws-staging"
image_tag      = "v2.3.7"
ssh_pub_keys   = ["ssh-ed25519 AAAA... you@host"]
iap_user_group = "cloudws-admins@example.com"
enable_gke     = false
enable_ws      = true
enable_gpu     = false
EOF

terraform init
terraform plan
terraform apply
```

## Push path

Once the WIF pool and GAR repo exist, the `push-gar.yml` workflow
authenticates with OIDC, pushes to GAR, and signs keyless with cosign. The
`build-gcp-artifact.yml` workflow builds the raw disk via
`bootc-image-builder --type gce`, uploads to the staging bucket, and creates
a new `google_compute_image` via `gcloud`.

## Access

- **SSH through IAP**: see `iap_ssh_cmd` output.
- **Cockpit through IAP**: see `iap_cockpit_cmd` output (opens `localhost:9090`).
- **Workstation IDE**: `https://console.cloud.google.com/workstations/...`.
- **VDI (browser, IAP-fronted)**: configure a DNS record for `var.vdi_domain`
  pointing at the HTTPS load balancer (see the companion `lb.tf` if enabled).
