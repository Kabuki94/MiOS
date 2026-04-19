variable "project_id"     { type = string }
variable "region"         { type = string  default = "us-central1" }
variable "zone"           { type = string  default = "us-central1-a" }
variable "github_repo"    { type = string  default = "Kabuki94/CloudWS-bootc" }
variable "image_tag"      { type = string  default = "latest" }
variable "gar_location"   { type = string  default = "us-central1" }
variable "gar_repo"       { type = string  default = "cloudws" }
variable "staging_bucket" { type = string }
variable "vdi_domain"     { type = string  default = "" }
variable "cloudws_size"   { type = number  default = 1 }
variable "ssh_pub_keys"   { type = list(string) default = [] }
variable "iap_user_group" { type = string  default = "" }
variable "enable_gke"     { type = bool    default = false }
variable "enable_ws"      { type = bool    default = true }
variable "enable_gpu"     { type = bool    default = false }
variable "machine_type"   { type = string  default = "n2-standard-8" }
