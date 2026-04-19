# Runtime service account attached to the VM / workstation / GKE nodes.
resource "google_service_account" "vm" {
  account_id   = "cloudws-vm"
  display_name = "CloudWS VM runtime"
}

resource "google_artifact_registry_repository_iam_member" "vm_reader" {
  project    = var.project_id
  location   = google_artifact_registry_repository.cloudws.location
  repository = google_artifact_registry_repository.cloudws.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.vm.email}"
}

# ---- Workload Identity Federation for GitHub Actions ----
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"

  oidc { issuer_uri = "https://token.actions.githubusercontent.com" }

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
  }
  # Pin to the exact repo to prevent cross-tenant spoofing.
  attribute_condition = "assertion.repository == '${var.github_repo}'"
}

resource "google_service_account" "gha" {
  account_id   = "gha-cloudws-push"
  display_name = "GitHub Actions pusher"
}

resource "google_service_account_iam_member" "gha_wif" {
  service_account_id = google_service_account.gha.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}

resource "google_artifact_registry_repository_iam_member" "gha_writer" {
  project    = var.project_id
  location   = google_artifact_registry_repository.cloudws.location
  repository = google_artifact_registry_repository.cloudws.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.gha.email}"
}

resource "google_storage_bucket_iam_member" "gha_staging" {
  bucket = google_storage_bucket.staging.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.gha.email}"
}

# ---- IAP access for humans ----
resource "google_iap_tunnel_instance_iam_member" "admins" {
  count    = var.iap_user_group == "" ? 0 : 1
  project  = var.project_id
  zone     = var.zone
  instance = "cloudws-admin"
  role     = "roles/iap.tunnelResourceAccessor"
  member   = "group:${var.iap_user_group}"
}
