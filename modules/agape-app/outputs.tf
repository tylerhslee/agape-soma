output "app_uri" {
  value       = module.runtime.service_uris["app"]
  description = "URL of the application service."
}

output "studio_uri" {
  value       = module.runtime.service_uris["studio"]
  description = "URL of the Agape Studio admin service."
}

output "state_bucket_name" {
  value       = module.foundation.state_bucket_name
  description = "GCS bucket carrying the persistent Agape project and app state."
}

output "artifact_repository_url" {
  value       = module.foundation.artifact_repository_url
  description = "Artifact Registry base URL for pushing the app/studio images."
}

output "runtime_service_account" {
  value       = module.foundation.runtime_service_account
  description = "Runtime service account email."
}

output "secret_ids" {
  value       = module.foundation.secret_ids
  description = "Map of secret short name => Secret Manager secret id (includes anthropic-api-key and studio-access-token)."
}
