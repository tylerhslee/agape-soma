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
  value       = var.enable_state_bucket ? google_storage_bucket.runtime_state[0].name : null
  description = "GCS bucket mounted into Cloud Run for file-backed state, or null when disabled."
}

output "secret_ids" {
  value       = { for short, secret in google_secret_manager_secret.secrets : short => secret.secret_id }
  description = "Map of short secret name => Secret Manager secret id for every created secret."
}
