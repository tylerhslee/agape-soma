output "artifact_repository" {
  value       = google_artifact_registry_repository.containers.repository_id
  description = "Artifact Registry repository id for runtime containers."
}

output "artifact_repository_url" {
  value       = "${google_artifact_registry_repository.containers.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.containers.repository_id}"
  description = "Artifact Registry base URL for Docker images."
}

output "runtime_service_account" {
  value       = google_service_account.runtime.email
  description = "Service account used by Soma runtime services and jobs."
}

output "state_bucket_name" {
  value       = google_storage_bucket.runtime_state.name
  description = "GCS bucket mounted into Cloud Run for current file-backed state."
}

output "secret_ids" {
  value       = { for key, secret in google_secret_manager_secret.secrets : key => secret.secret_id }
  description = "Secret Manager secret ids created for runtime configuration."
}

output "app_env_secret" {
  value       = google_secret_manager_secret.secrets["app_env"].secret_id
  description = "Secret id reserved for app-level environment payloads."
}

output "plaid_client_id_secret" {
  value       = google_secret_manager_secret.secrets["plaid_client_id"].secret_id
  description = "Secret id reserved for Plaid client id."
}

output "plaid_secret_secret" {
  value       = google_secret_manager_secret.secrets["plaid_secret"].secret_id
  description = "Secret id reserved for Plaid secret."
}
