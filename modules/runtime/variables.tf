variable "project_id" {
  type        = string
  description = "GCP project id."
}

variable "region" {
  type        = string
  description = "GCP region for Cloud Run, Scheduler, and Pub/Sub resources."
}

variable "name" {
  type        = string
  description = "Short runtime name, for example whale-dev."
}

variable "labels" {
  type        = map(string)
  description = "Additional labels applied to supported resources."
  default     = {}
}

variable "service_account_email" {
  type        = string
  description = "Runtime service account email."
}

variable "state_bucket_name" {
  type        = string
  description = "GCS bucket mounted into runtime containers at /data."
}

variable "api_image" {
  type        = string
  description = "Container image for the Whale API / Soma sensory gateway."
}

variable "worker_image" {
  type        = string
  description = "Container image for one-shot sensor and classifier workers."
}

variable "ui_image" {
  type        = string
  description = "Container image for the Whale UI."
}

variable "studio_image" {
  type        = string
  description = "Optional Agape Studio image to run beside Whale on the same Soma runtime."
  default     = null
}

variable "plaid_env" {
  type        = string
  description = "Plaid environment passed to runtime containers."
  default     = "sandbox"
}

variable "common_env" {
  type        = map(string)
  description = "Plain environment variables shared by API, worker, and Studio containers."
  default     = {}
}

variable "api_env" {
  type        = map(string)
  description = "Additional plain environment variables for the API service."
  default     = {}
}

variable "worker_env" {
  type        = map(string)
  description = "Additional plain environment variables for worker jobs."
  default     = {}
}

variable "ui_env" {
  type        = map(string)
  description = "Additional plain environment variables for the UI gateway service."
  default     = {}
}

variable "studio_env" {
  type        = map(string)
  description = "Additional plain environment variables for the optional Studio service."
  default     = {}
}

variable "secret_env" {
  type        = map(string)
  description = "Environment variable name to Secret Manager secret id. The runtime reads version latest."
  default     = {}
}

variable "allow_unauthenticated_api" {
  type        = bool
  description = "Grant allUsers run.invoker on the API service. Useful for local demo CORS; tighten later."
  default     = false
}

variable "allow_unauthenticated_ui" {
  type        = bool
  description = "Grant allUsers run.invoker on the UI service."
  default     = false
}

variable "allow_unauthenticated_studio" {
  type        = bool
  description = "Grant allUsers run.invoker on Studio when studio_image is set."
  default     = false
}

variable "invoker_members" {
  type        = list(string)
  description = "IAM members allowed to invoke private Cloud Run services, for example user:name@example.com or serviceAccount:name@project.iam.gserviceaccount.com."
  default     = []
}

variable "enable_iap_ui" {
  type        = bool
  description = "Enable Identity-Aware Proxy on the UI Cloud Run service."
  default     = false
}

variable "iap_access_members" {
  type        = list(string)
  description = "IAM members allowed through IAP, for example user:name@example.com."
  default     = []
}

variable "api_ingress" {
  type        = string
  description = "Cloud Run ingress setting for the API service."
  default     = "INGRESS_TRAFFIC_ALL"
}

variable "ui_ingress" {
  type        = string
  description = "Cloud Run ingress setting for the UI service."
  default     = "INGRESS_TRAFFIC_ALL"
}

variable "studio_ingress" {
  type        = string
  description = "Cloud Run ingress setting for the optional Studio service."
  default     = "INGRESS_TRAFFIC_ALL"
}

variable "api_min_instances" {
  type        = number
  description = "Minimum API instances."
  default     = 0
}

variable "api_max_instances" {
  type        = number
  description = "Maximum API instances."
  default     = 2
}

variable "ui_min_instances" {
  type        = number
  description = "Minimum UI instances."
  default     = 0
}

variable "ui_max_instances" {
  type        = number
  description = "Maximum UI instances."
  default     = 2
}

variable "studio_min_instances" {
  type        = number
  description = "Minimum Studio instances."
  default     = 0
}

variable "studio_max_instances" {
  type        = number
  description = "Maximum Studio instances."
  default     = 1
}

variable "api_cpu" {
  type        = string
  description = "API CPU limit."
  default     = "1"
}

variable "api_memory" {
  type        = string
  description = "API memory limit."
  default     = "512Mi"
}

variable "ui_cpu" {
  type        = string
  description = "UI CPU limit."
  default     = "1"
}

variable "ui_memory" {
  type        = string
  description = "UI memory limit."
  default     = "512Mi"
}

variable "studio_port" {
  type        = number
  description = "Container port for the optional Studio service."
  default     = 8080
}

variable "sync_schedule" {
  type        = string
  description = "Cron schedule for transaction sync."
  default     = "*/30 * * * *"
}

variable "sync_time_zone" {
  type        = string
  description = "Time zone for Cloud Scheduler."
  default     = "America/Los_Angeles"
}

variable "enable_cloud_sql" {
  type        = bool
  description = "Create a Cloud SQL Postgres instance. The current app uses GCS-backed file state, so this can stay false for low-cost demos."
  default     = false
}

variable "database_name" {
  type        = string
  description = "Database name when enable_cloud_sql is true."
  default     = "whale"
}

variable "database_user" {
  type        = string
  description = "Database user when enable_cloud_sql is true."
  default     = "whale"
}

variable "database_tier" {
  type        = string
  description = "Cloud SQL tier when enable_cloud_sql is true."
  default     = "db-f1-micro"
}

variable "database_version" {
  type        = string
  description = "Cloud SQL database version when enable_cloud_sql is true."
  default     = "POSTGRES_15"
}

variable "database_deletion_protection" {
  type        = bool
  description = "Cloud SQL deletion protection."
  default     = false
}
