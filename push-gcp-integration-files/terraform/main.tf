terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google      = { source = "hashicorp/google",      version = "~> 7.0" }
    google-beta = { source = "hashicorp/google-beta", version = "~> 7.0" }
  }
}

provider "google"      { project = var.project_id region = var.region zone = var.zone }
provider "google-beta" { project = var.project_id region = var.region zone = var.zone }

# -------------------- VPC + Cloud NAT --------------------
resource "google_compute_network" "vpc" {
  name                    = "cloudws-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "nodes" {
  name                     = "cloudws-nodes"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = "10.10.0.0/20"
  private_ip_google_access = true
  secondary_ip_range { range_name = "pods"     ip_cidr_range = "10.20.0.0/14" }
  secondary_ip_range { range_name = "services" ip_cidr_range = "10.24.0.0/20" }
}

resource "google_compute_router" "nat" {
  name    = "cloudws-nat"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "cloudws-nat"
  router                             = google_compute_router.nat.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  log_config { enable = true filter = "ERRORS_ONLY" }
}

# -------------------- Firewalls --------------------
resource "google_compute_firewall" "iap_ingress" {
  name          = "allow-iap-ingress"
  network       = google_compute_network.vpc.name
  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]
  allow { protocol = "tcp" ports = ["22","3389","9090"] }
  target_tags   = ["iap-ssh"]
}

resource "google_compute_firewall" "lb_ingress" {
  name          = "allow-lb-ingress"
  network       = google_compute_network.vpc.name
  direction     = "INGRESS"
  source_ranges = ["130.211.0.0/22","35.191.0.0/16"]
  allow { protocol = "tcp" ports = ["443","8443"] }
  target_tags   = ["cloudws-vdi"]
}

# -------------------- Artifact Registry --------------------
resource "google_artifact_registry_repository" "cloudws" {
  location      = var.gar_location
  repository_id = var.gar_repo
  format        = "DOCKER"
  description   = "CloudWS-bootc images"

  cleanup_policies {
    id     = "keep-recent-5"
    action = "KEEP"
    most_recent_versions { keep_count = 5 }
  }
  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"
    condition { tag_state = "UNTAGGED" older_than = "604800s" }
  }
}

# -------------------- GCS staging --------------------
resource "google_storage_bucket" "staging" {
  name                        = var.staging_bucket
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false
  lifecycle_rule {
    action    { type = "Delete" }
    condition { age  = 7 }
  }
}

# -------------------- Custom GCE Image --------------------
# Expects disk.raw.tar.gz pre-uploaded by the build-gcp-artifact.yml workflow.
resource "google_compute_image" "cloudws" {
  name   = "cloudws-bootc-${replace(var.image_tag, ".", "-")}"
  family = "cloudws-bootc"

  raw_disk {
    source         = "https://storage.googleapis.com/${google_storage_bucket.staging.name}/cloudws-${var.image_tag}/disk.raw.tar.gz"
    container_type = "TAR"
  }

  guest_os_features { type = "UEFI_COMPATIBLE" }
  guest_os_features { type = "GVNIC" }
  guest_os_features { type = "VIRTIO_SCSI_MULTIQUEUE" }
}

# -------------------- VM instance template --------------------
resource "google_compute_instance_template" "cloudws" {
  name_prefix  = "cloudws-"
  machine_type = var.machine_type
  region       = var.region

  disk {
    source_image = google_compute_image.cloudws.self_link
    auto_delete  = true
    boot         = true
    disk_type    = "pd-ssd"
    disk_size_gb = 100
  }

  network_interface {
    subnetwork = google_compute_subnetwork.nodes.id
  }

  service_account {
    email  = google_service_account.vm.email
    scopes = ["cloud-platform"]
  }

  dynamic "guest_accelerator" {
    for_each = var.enable_gpu ? [1] : []
    content {
      type  = "nvidia-l4"
      count = 1
    }
  }
  scheduling {
    on_host_maintenance = var.enable_gpu ? "TERMINATE" : "MIGRATE"
    automatic_restart   = true
    provisioning_model  = "STANDARD"
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = {
    enable-oslogin = "TRUE"
    ssh-keys       = join("\n", [for k in var.ssh_pub_keys : "cloudws:${k}"])
  }
  tags = ["iap-ssh","cloudws-vdi"]
  lifecycle { create_before_destroy = true }
}

resource "google_compute_region_instance_group_manager" "cloudws" {
  name               = "cloudws-mig"
  region             = var.region
  base_instance_name = "cloudws"
  target_size        = var.cloudws_size

  version { instance_template = google_compute_instance_template.cloudws.id }
  named_port { name = "https" port = 443 }
}
