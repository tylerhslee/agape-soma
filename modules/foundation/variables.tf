variable "project_id" {
  type        = string
  description = "GCP project id."
}

variable "region" {
  type        = string
  description = "Primary GCP region for regional Soma resources."
}

variable "name" {
  type        = string
  description = "Short runtime name, used as a prefix for all created resources (for example league-dev)."
}

variable "labels" {
  type        = map(string)
  description = "Additional labels applied to supported resources."
  default     = {}
}

variable "secret_names" {
  type        = set(string)
  description = "Short secret names to create in Secret Manager. Each becomes a secret id named <name>-<secret_name> and is readable by the runtime service account. App-specific: e.g. [\"riot-api-key\"] or [\"plaid-client-id\", \"plaid-secret\"]. Empty by default."
  default     = []
}

variable "additional_gcp_services" {
  type        = list(string)
  description = "GCP service APIs to enable in addition to the base set (run, artifactregistry, cloudbuild, iam, secretmanager, storage). Enable only what the app uses, e.g. [\"pubsub.googleapis.com\", \"cloudscheduler.googleapis.com\", \"sqladmin.googleapis.com\", \"iap.googleapis.com\", \"firestore.googleapis.com\"]."
  default     = []
}

variable "runtime_roles" {
  type        = list(string)
  description = "Project-level IAM roles granted to the runtime service account. Defaults to log writing only; add app-specific roles such as roles/pubsub.publisher, roles/cloudsql.client, or roles/datastore.user as needed."
  default     = ["roles/logging.logWriter"]
}

variable "enable_state_bucket" {
  type        = bool
  description = "Create a GCS bucket for file-backed runtime state (mounted into Cloud Run by the runtime module). Disable for apps that keep all state in a database."
  default     = true
}

variable "state_bucket_name" {
  type        = string
  description = "Optional globally unique bucket name for file-backed runtime state. Defaults to <project_id>-<name>-runtime-state."
  default     = null
}

variable "grant_cloudbuild_builder" {
  type        = bool
  description = "Grant roles/cloudbuild.builds.builder to the project's compute default service account so `gcloud builds submit` works on fresh projects."
  default     = true
}
