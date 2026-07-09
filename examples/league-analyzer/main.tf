// Minimal Soma consumer: one Cloud Run service that serves both an API and its
// built static UI, a GCS-mounted state bucket for a SQLite file, and one secret.

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
  default = "league-dev"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "foundation" {
  source       = "../../modules/foundation"
  project_id   = var.project_id
  region       = var.region
  name         = var.name
  secret_names = ["riot-api-key"]
}

module "runtime" {
  source                = "../../modules/runtime"
  project_id            = var.project_id
  region                = var.region
  name                  = var.name
  service_account_email = module.foundation.runtime_service_account
  state_bucket_name     = module.foundation.state_bucket_name

  services = {
    api = {
      image                 = "${module.foundation.artifact_repository_url}/app:latest"
      port                  = 8787
      mount_state           = true
      allow_unauthenticated = true
      env                   = { PORT = "8787" }
      secret_env            = { RIOT_API_KEY = module.foundation.secret_ids["riot-api-key"] }
    }
  }
}

output "api_uri" {
  value = module.runtime.service_uris["api"]
}
