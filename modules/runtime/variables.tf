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
  description = "Short runtime name, used as a prefix for all created resources (for example league-dev)."
}

variable "labels" {
  type        = map(string)
  description = "Additional labels applied to supported resources."
  default     = {}
}

variable "service_account_email" {
  type        = string
  description = "Runtime service account email (from the foundation module)."
}

variable "state_bucket_name" {
  type        = string
  description = "GCS bucket to mount into services/jobs that set mount_state = true. Required only if anything mounts state."
  default     = null
}

variable "common_env" {
  type        = map(string)
  description = "Plain environment variables merged into every service and job container."
  default     = {}
}

variable "services" {
  description = "Cloud Run services to create, keyed by short name (resource name becomes <name>-<key>). All fields except image are optional."
  type = map(object({
    image                 = string
    port                  = optional(number, 8080)
    env                   = optional(map(string), {})
    secret_env            = optional(map(string), {}) # env var name => Secret Manager secret id (reads version "latest")
    cpu                   = optional(string, "1")
    memory                = optional(string, "512Mi")
    min_instances         = optional(number, 0)
    max_instances         = optional(number, 2)
    ingress               = optional(string, "INGRESS_TRAFFIC_ALL")
    allow_unauthenticated = optional(bool, false)
    invoker_members       = optional(list(string), [])
    mount_state           = optional(bool, false)
    state_mount_path      = optional(string, "/data")
    enable_iap            = optional(bool, false)
    iap_members           = optional(list(string), [])
    attach_cloud_sql      = optional(bool, false)
  }))
  default = {}
}

variable "jobs" {
  description = "Cloud Run jobs to create, keyed by short name (resource name becomes <name>-<key>). All fields except image are optional."
  type = map(object({
    image            = string
    env              = optional(map(string), {})
    secret_env       = optional(map(string), {})
    mount_state      = optional(bool, false)
    state_mount_path = optional(string, "/data")
    attach_cloud_sql = optional(bool, false)
  }))
  default = {}
}

variable "pubsub_topics" {
  type        = set(string)
  description = "Pub/Sub topic short names to create (topic name becomes <name>-<topic>)."
  default     = []
}

variable "pubsub_subscriptions" {
  description = "Pub/Sub subscriptions to create, keyed by short name. `topic` references a key in pubsub_topics."
  type = map(object({
    topic = string
  }))
  default = {}
}

variable "scheduler_jobs" {
  description = "Cloud Scheduler jobs that make an authenticated (OIDC) HTTP call to one of the services, keyed by short name."
  type = map(object({
    schedule       = string
    target_service = string # key in var.services
    path           = optional(string, "/")
    http_method    = optional(string, "POST")
    time_zone      = optional(string, "Etc/UTC")
    description    = optional(string, null)
  }))
  default = {}
}

variable "inject_topic_env" {
  type        = bool
  description = "Inject every created topic's id into all services/jobs as env vars named topic_env_prefix followed by the upper-snake-case topic name."
  default     = false
}

variable "topic_env_prefix" {
  type        = string
  description = "Prefix for auto-injected topic env vars when inject_topic_env is true."
  default     = "SOMA_TOPIC_"
}

variable "enable_cloud_sql" {
  type        = bool
  description = "Create a Cloud SQL Postgres instance and attach it to services/jobs that set attach_cloud_sql = true. Standard libpq env (PGHOST, PGDATABASE, PGUSER) and a PGPASSWORD secret are injected into those containers."
  default     = false
}

variable "database_name" {
  type        = string
  description = "Database name when enable_cloud_sql is true."
  default     = "app"
}

variable "database_user" {
  type        = string
  description = "Database user when enable_cloud_sql is true."
  default     = "app"
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
