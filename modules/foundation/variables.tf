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
  description = "Short runtime name, for example whale-dev."
}

variable "labels" {
  type        = map(string)
  description = "Additional labels applied to supported resources."
  default     = {}
}

variable "state_bucket_name" {
  type        = string
  description = "Optional globally unique bucket name for file-backed runtime state. Defaults to project-name-runtime-state."
  default     = null
}
