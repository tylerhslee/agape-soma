variable "project_id" {
  type        = string
  description = "GCP project id."
}

variable "region" {
  type        = string
  description = "GCP region."
}

variable "name" {
  type        = string
  description = "Short runtime name, used as a prefix for all created resources (for example league-dev, whale-dev, factcheck-dev)."
}

variable "labels" {
  type        = map(string)
  description = "Additional labels applied to supported resources."
  default     = {}
}

variable "app_image" {
  type        = string
  description = "Container image for the app service (the api target of the standard agape-app Dockerfile)."
}

variable "studio_image" {
  type        = string
  description = "Container image for the Agape Studio admin service (the studio target of the standard agape-app Dockerfile)."
}

variable "app_port" {
  type        = number
  description = "Container port for the app service."
  default     = 8080
}

variable "agape_mount_path" {
  type        = string
  description = "Where the persistent Agape project (programs, manifest, knowledge substrate) lives on the state mount. Shared by the app and Studio: Studio edits are what the app executes."
  default     = "/data/agape"
}

variable "agape_dir_env_var" {
  type        = string
  description = "Name of the env var (set on both services) that carries agape_mount_path. Match what your app's host layer reads."
  default     = "AGAPE_PROJECT_DIR"
}

variable "app_env" {
  type        = map(string)
  description = "Additional plain env vars for the app service."
  default     = {}
}

variable "studio_env" {
  type        = map(string)
  description = "Additional plain env vars for the Studio service."
  default     = {}
}

variable "extra_secret_names" {
  type        = list(string)
  description = "Secret Manager short names to create beyond the built-ins (anthropic-api-key, studio-access-token)."
  default     = []
}

variable "app_secret_env" {
  type        = map(string)
  description = "Extra secret env for the app service: env var name => secret SHORT name (must appear in extra_secret_names). ANTHROPIC_API_KEY is always injected."
  default     = {}
}

variable "enable_cloud_sql" {
  type        = bool
  description = "Create a Cloud SQL Postgres instance and attach it to the app service (libpq env + PGPASSWORD secret injected)."
  default     = false
}

variable "database_tier" {
  type        = string
  description = "Cloud SQL tier when enable_cloud_sql is true."
  default     = "db-f1-micro"
}

variable "additional_gcp_services" {
  type        = list(string)
  description = "GCP service APIs to enable beyond the pattern's own needs."
  default     = []
}

variable "extra_runtime_roles" {
  type        = list(string)
  description = "Project IAM roles for the runtime service account beyond the pattern's defaults."
  default     = []
}

variable "enable_iap" {
  type        = bool
  description = "Front both services with Identity-Aware Proxy (Google sign-in). Requires an OAuth consent screen (brand) and the IAP service identity on the project — the standard deploy script provisions both."
  default     = true
}

variable "iap_members" {
  type        = list(string)
  description = "IAM members allowed through IAP on both services, e.g. [\"user:me@example.com\"]."
  default     = []
}

variable "allow_unauthenticated" {
  type        = bool
  description = "Grant allUsers run.invoker on the app service (org policy may block; prefer IAP)."
  default     = false
}

variable "invoker_members" {
  type        = list(string)
  description = "IAM members allowed to invoke the app service when private."
  default     = []
}

variable "studio_require_token" {
  type        = bool
  description = "Also require Studio's own access token (?token=…) on top of IAP, as defense-in-depth. Off by default: IAP already authenticates every request, and the token was designed for unauthenticated tunnels. When true, the studio-access-token secret is injected and the URL needs the token appended."
  default     = false
}

variable "app_min_instances" {
  type        = number
  description = "Minimum app instances (set 1 to avoid cold starts on gated coach turns)."
  default     = 0
}

variable "app_max_instances" {
  type        = number
  description = "Maximum app instances. Keep 1 while the app uses single-writer state (e.g. SQLite on the mount); raise freely on Cloud SQL-only state."
  default     = 1
}
