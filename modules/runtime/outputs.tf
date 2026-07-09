output "service_uris" {
  value       = { for key, svc in google_cloud_run_v2_service.services : key => svc.uri }
  description = "Map of service short name => Cloud Run URI."
}

output "service_names" {
  value       = { for key, svc in google_cloud_run_v2_service.services : key => svc.name }
  description = "Map of service short name => full Cloud Run service name."
}

output "job_names" {
  value       = { for key, job in google_cloud_run_v2_job.jobs : key => job.name }
  description = "Map of job short name => full Cloud Run job name."
}

output "topic_ids" {
  value       = { for key, topic in google_pubsub_topic.topics : key => topic.id }
  description = "Map of topic short name => Pub/Sub topic id."
}

output "subscription_ids" {
  value       = { for key, sub in google_pubsub_subscription.subscriptions : key => sub.id }
  description = "Map of subscription short name => Pub/Sub subscription id."
}

output "scheduler_job_names" {
  value       = { for key, job in google_cloud_scheduler_job.jobs : key => job.name }
  description = "Map of scheduler short name => Cloud Scheduler job name."
}

output "database_instance" {
  value       = try(google_sql_database_instance.postgres[0].name, null)
  description = "Optional Cloud SQL instance name, or null when disabled."
}

output "database_connection_name" {
  value       = try(google_sql_database_instance.postgres[0].connection_name, null)
  description = "Optional Cloud SQL connection name, or null when disabled."
}
