resource "google_service_account" "gke_node" {
  count        = var.enable_gke ? 1 : 0
  account_id   = "cloudws-gke-node"
  display_name = "CloudWS GKE node SA"
}

resource "google_artifact_registry_repository_iam_member" "gke_reader" {
  count      = var.enable_gke ? 1 : 0
  project    = var.project_id
  location   = google_artifact_registry_repository.cloudws.location
  repository = google_artifact_registry_repository.cloudws.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.gke_node[0].email}"
}

resource "google_container_cluster" "gke" {
  count    = var.enable_gke ? 1 : 0
  name     = "cloudws-gke"
  location = var.region
  network  = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.nodes.id

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  workload_identity_config { workload_pool = "${var.project_id}.svc.id.goog" }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  release_channel { channel = "REGULAR" }
}

resource "google_container_node_pool" "kubevirt" {
  count    = var.enable_gke ? 1 : 0
  name     = "kubevirt-nested"
  cluster  = google_container_cluster.gke[0].id
  location = var.region

  node_config {
    machine_type    = "n2-standard-8"
    image_type      = "UBUNTU_CONTAINERD"
    service_account = google_service_account.gke_node[0].email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    labels          = { "nested-virtualization" = "enabled" }
    workload_metadata_config { mode = "GKE_METADATA" }
    advanced_machine_features { enable_nested_virtualization = true }
  }
  node_count = 2
}
