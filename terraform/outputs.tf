output "gar_image_ref" {
  value = "${var.gar_location}-docker.pkg.dev/${var.project_id}/${var.gar_repo}/cloudws-bootc:${var.image_tag}"
}

output "custom_image_self_link" {
  value = google_compute_image.cloudws.self_link
}

output "mig_name" {
  value = google_compute_region_instance_group_manager.cloudws.name
}

output "iap_ssh_cmd" {
  value       = "gcloud compute ssh --tunnel-through-iap cloudws-0 --zone=${var.zone} --project=${var.project_id}"
  description = "SSH through IAP without a public IP"
}

output "iap_cockpit_cmd" {
  value       = "gcloud compute start-iap-tunnel cloudws-0 9090 --local-host-port=localhost:9090 --zone=${var.zone}"
}

output "workstation_url" {
  value     = var.enable_ws ? "https://console.cloud.google.com/workstations/list?project=${var.project_id}" : ""
  sensitive = false
}

output "wif_provider" {
  value = google_iam_workload_identity_pool_provider.github.name
}

output "wif_service_account" {
  value = google_service_account.gha.email
}
