resource "google_service_account" "ws" {
  count        = var.enable_ws ? 1 : 0
  account_id   = "cloudws-ws"
  display_name = "CloudWS Workstations runtime"
}

resource "google_artifact_registry_repository_iam_member" "ws_reader" {
  count      = var.enable_ws ? 1 : 0
  project    = var.project_id
  location   = google_artifact_registry_repository.cloudws.location
  repository = google_artifact_registry_repository.cloudws.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.ws[0].email}"
}

resource "google_workstations_workstation_cluster" "ws" {
  count                  = var.enable_ws ? 1 : 0
  workstation_cluster_id = "cloudws"
  location               = var.region
  network                = google_compute_network.vpc.id
  subnetwork             = google_compute_subnetwork.nodes.id
}

resource "google_workstations_workstation_config" "ws" {
  count                  = var.enable_ws ? 1 : 0
  workstation_config_id  = "cloudws-bootc"
  workstation_cluster_id = google_workstations_workstation_cluster.ws[0].workstation_cluster_id
  location               = var.region

  host {
    gce_instance {
      machine_type                = var.machine_type
      boot_disk_size_gb           = 100
      disable_public_ip_addresses = true
      service_account             = google_service_account.ws[0].email
      shielded_instance_config {
        enable_secure_boot          = true
        enable_vtpm                 = true
        enable_integrity_monitoring = true
      }
    }
  }

  container {
    image = "${var.gar_location}-docker.pkg.dev/${var.project_id}/${var.gar_repo}/cloudws-bootc:${var.image_tag}"
    env = { CLOUDWS_MODE = "workstation" }
  }

  idle_timeout    = "7200s"
  running_timeout = "43200s"
}
