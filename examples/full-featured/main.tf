// Full Soma consumer exercising every building block: multiple services (one
// with IAP, one public with Cloud SQL), worker jobs, Pub/Sub topics and
// subscriptions, a scheduler, injected topic env, and Cloud SQL. This mirrors
// the shape Whale would use if it migrated from v0.1.0 to the generalized runtime.

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
  default = "whale-dev"
}
variable "operator" {
  type    = string
  default = "user:owner@example.com"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "foundation" {
  source                  = "../../modules/foundation"
  project_id              = var.project_id
  region                  = var.region
  name                    = var.name
  secret_names            = ["plaid-client-id", "plaid-secret", "openai-api-key", "app-env"]
  additional_gcp_services = ["pubsub.googleapis.com", "cloudscheduler.googleapis.com", "sqladmin.googleapis.com", "iap.googleapis.com", "firestore.googleapis.com"]
  runtime_roles           = ["roles/logging.logWriter", "roles/pubsub.publisher", "roles/pubsub.subscriber", "roles/cloudsql.client", "roles/datastore.user"]
}

module "runtime" {
  source                = "../../modules/runtime"
  project_id            = var.project_id
  region                = var.region
  name                  = var.name
  service_account_email = module.foundation.runtime_service_account
  state_bucket_name     = module.foundation.state_bucket_name

  common_env       = { SOMA_RUNTIME_NAME = var.name }
  inject_topic_env = true
  enable_cloud_sql = true

  pubsub_topics = ["sensory-events", "transaction-observed", "classification-requested", "decision-events", "ledger-events"]
  pubsub_subscriptions = {
    "classifier-requests" = { topic = "classification-requested" }
    "ledger-events"       = { topic = "ledger-events" }
  }

  services = {
    api = {
      image            = "${module.foundation.artifact_repository_url}/api:latest"
      port             = 8787
      mount_state      = true
      attach_cloud_sql = true
      invoker_members  = [var.operator]
      secret_env       = { PLAID_CLIENT_ID = module.foundation.secret_ids["plaid-client-id"] }
    }
    ui = {
      image       = "${module.foundation.artifact_repository_url}/ui:latest"
      enable_iap  = true
      iap_members = [var.operator]
    }
    studio = {
      image       = "${module.foundation.artifact_repository_url}/studio:latest"
      mount_state = true
    }
  }

  jobs = {
    sensor-sync      = { image = "${module.foundation.artifact_repository_url}/worker:latest", attach_cloud_sql = true, env = { WORKER_MODE = "sync-only" } }
    classifier-agent = { image = "${module.foundation.artifact_repository_url}/worker:latest", attach_cloud_sql = true, env = { WORKER_MODE = "classify" } }
  }

  scheduler_jobs = {
    transaction-sync = { schedule = "*/30 * * * *", target_service = "api", path = "/plaid/sync", time_zone = "America/Los_Angeles" }
  }
}
