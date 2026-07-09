output "api_uri" {
  value       = google_cloud_run_v2_service.api.uri
  description = "Whale API / Soma sensory gateway URI."
}

output "ui_uri" {
  value       = google_cloud_run_v2_service.ui.uri
  description = "Whale UI URI."
}

output "studio_uri" {
  value       = try(google_cloud_run_v2_service.studio[0].uri, null)
  description = "Optional Agape Studio URI."
}

output "signal_topics" {
  value       = { for key, topic in google_pubsub_topic.signals : key => topic.id }
  description = "Soma signal topics used as the cloud runtime event bus."
}

output "classifier_requests_subscription" {
  value       = google_pubsub_subscription.classifier_requests.id
  description = "Subscription reserved for classifier workers."
}

output "ledger_events_subscription" {
  value       = google_pubsub_subscription.ledger_events.id
  description = "Subscription reserved for ledger/materialization workers."
}

output "sensor_sync_job" {
  value       = google_cloud_run_v2_job.sensor_sync.name
  description = "Cloud Run job for Plaid/sensor ingestion."
}

output "classifier_agent_job" {
  value       = google_cloud_run_v2_job.classifier_agent.name
  description = "Cloud Run job for Agape classifier passes."
}

output "sync_scheduler_job" {
  value       = google_cloud_scheduler_job.transaction_sync.name
  description = "Cloud Scheduler job that triggers the current sync/classifier path."
}

output "database_instance" {
  value       = try(google_sql_database_instance.postgres[0].name, null)
  description = "Optional Cloud SQL instance name."
}
