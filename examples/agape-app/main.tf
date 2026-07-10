// The agape-app pattern, as league-analyzer consumes it: one Agape-powered
// app service + Agape Studio as the admin surface, sharing a persistent Agape
// project on the state mount, key from Secret Manager, both behind IAP.

terraform {
  required_version = ">= 1.7.0"
  required_providers {
    google = { source = "hashicorp/google", version = ">= 6.0, < 8.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

variable "project_id" { type = string }
variable "region" {
  type    = string
  default = "us-west1"
}
variable "name" {
  type    = string
  default = "myapp-dev"
}
variable "app_image" { type = string }
variable "studio_image" { type = string }
variable "iap_members" {
  type    = list(string)
  default = []
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "agape_app" {
  source     = "../../modules/agape-app"
  project_id = var.project_id
  region     = var.region
  name       = var.name

  app_image    = var.app_image
  studio_image = var.studio_image
  iap_members  = var.iap_members

  # App-specific knobs, all optional:
  enable_cloud_sql   = true
  extra_secret_names = ["example-provider-key"]
  app_secret_env     = { EXAMPLE_PROVIDER_KEY = "example-provider-key" }
  app_env            = { EXAMPLE_FLAG = "on" }
}

output "app_uri" {
  value = module.agape_app.app_uri
}

output "studio_uri" {
  value = module.agape_app.studio_uri
}
