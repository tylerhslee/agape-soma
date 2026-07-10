data "google_project" "current" {
  project_id = var.project_id
}

locals {
  labels = merge(var.labels, {
    app     = var.name
    layer   = "soma-runtime"
    managed = "terraform"
  })

  cloud_sql_connection_name = var.enable_cloud_sql ? google_sql_database_instance.postgres[0].connection_name : null

  # Standard libpq connection env for containers that attach Cloud SQL. The app
  # chooses how to consume it; no app-specific backend selector is injected.
  database_env = var.enable_cloud_sql ? {
    PGDATABASE = var.database_name
    PGHOST     = "/cloudsql/${local.cloud_sql_connection_name}"
    PGUSER     = var.database_user
  } : {}

  database_secret_env = var.enable_cloud_sql ? {
    PGPASSWORD = google_secret_manager_secret.database_password[0].secret_id
  } : {}

  topic_env = var.inject_topic_env ? {
    for short, topic in google_pubsub_topic.topics :
    "${var.topic_env_prefix}${upper(replace(short, "-", "_"))}" => topic.id
  } : {}

  iap_service_agent = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-iap.iam.gserviceaccount.com"

  # Flattened (service, member) pairs for private run.invoker bindings.
  service_invokers = merge(concat([{}], [
    for svc_key, svc in var.services : {
      for member in svc.invoker_members :
      "${svc_key}:${member}" => { service = svc_key, member = member }
    }
  ])...)

  # Flattened (service, member) pairs for IAP accessors (only IAP-enabled services).
  iap_accessors = merge(concat([{}], [
    for svc_key, svc in var.services : {
      for member in svc.iap_members :
      "${svc_key}:${member}" => { service = svc_key, member = member }
    } if svc.enable_iap
  ])...)

  iap_services      = toset([for svc_key, svc in var.services : svc_key if svc.enable_iap])
  public_services   = toset([for svc_key, svc in var.services : svc_key if svc.allow_unauthenticated])
  scheduler_targets = toset([for k, j in var.scheduler_jobs : j.target_service])
}

#
# Pub/Sub
#
resource "google_pubsub_topic" "topics" {
  for_each = var.pubsub_topics

  project = var.project_id
  name    = "${var.name}-${each.value}"
  labels  = local.labels
}

resource "google_pubsub_subscription" "subscriptions" {
  for_each = var.pubsub_subscriptions

  project = var.project_id
  name    = "${var.name}-${each.key}"
  topic   = google_pubsub_topic.topics[each.value.topic].id
  labels  = local.labels
}

#
# Optional Cloud SQL (Postgres)
#
resource "google_sql_database_instance" "postgres" {
  count = var.enable_cloud_sql ? 1 : 0

  project             = var.project_id
  name                = "${var.name}-postgres"
  region              = var.region
  database_version    = var.database_version
  deletion_protection = var.database_deletion_protection

  settings {
    tier = var.database_tier
  }
}

resource "google_sql_database" "app" {
  count = var.enable_cloud_sql ? 1 : 0

  project  = var.project_id
  instance = google_sql_database_instance.postgres[0].name
  name     = var.database_name
}

resource "random_password" "database" {
  count = var.enable_cloud_sql ? 1 : 0

  length  = 32
  special = false
}

resource "google_sql_user" "app" {
  count = var.enable_cloud_sql ? 1 : 0

  project  = var.project_id
  instance = google_sql_database_instance.postgres[0].name
  name     = var.database_user
  password = random_password.database[0].result
}

resource "google_secret_manager_secret" "database_password" {
  count = var.enable_cloud_sql ? 1 : 0

  project   = var.project_id
  secret_id = "${var.name}-database-password"

  replication {
    auto {}
  }

  labels = local.labels
}

resource "google_secret_manager_secret_version" "database_password" {
  count = var.enable_cloud_sql ? 1 : 0

  secret      = google_secret_manager_secret.database_password[0].id
  secret_data = random_password.database[0].result
}

resource "google_secret_manager_secret_iam_member" "runtime_database_password" {
  count = var.enable_cloud_sql ? 1 : 0

  project   = var.project_id
  secret_id = google_secret_manager_secret.database_password[0].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.service_account_email}"
}

#
# Cloud Run services
#
resource "google_cloud_run_v2_service" "services" {
  for_each = var.services

  project     = var.project_id
  name        = "${var.name}-${each.key}"
  location    = var.region
  ingress     = each.value.ingress
  iap_enabled = each.value.enable_iap
  labels      = local.labels

  template {
    service_account = var.service_account_email

    scaling {
      min_instance_count = each.value.min_instances
      max_instance_count = each.value.max_instances
    }

    dynamic "volumes" {
      for_each = each.value.mount_state && var.state_bucket_name != null ? [1] : []
      content {
        name = "runtime-state"
        gcs {
          bucket    = var.state_bucket_name
          read_only = each.value.mount_state_read_only
        }
      }
    }

    dynamic "volumes" {
      for_each = each.value.attach_cloud_sql && var.enable_cloud_sql ? [1] : []
      content {
        name = "cloudsql"
        cloud_sql_instance {
          instances = [local.cloud_sql_connection_name]
        }
      }
    }

    containers {
      image = each.value.image

      ports {
        container_port = each.value.port
      }

      resources {
        limits = {
          cpu    = each.value.cpu
          memory = each.value.memory
        }
      }

      dynamic "env" {
        for_each = merge(
          var.common_env,
          local.topic_env,
          each.value.attach_cloud_sql ? local.database_env : {},
          each.value.env
        )
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = merge(
          each.value.attach_cloud_sql ? local.database_secret_env : {},
          each.value.secret_env
        )
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value
              version = "latest"
            }
          }
        }
      }

      dynamic "volume_mounts" {
        for_each = each.value.mount_state && var.state_bucket_name != null ? [1] : []
        content {
          name       = "runtime-state"
          mount_path = each.value.state_mount_path
        }
      }

      dynamic "volume_mounts" {
        for_each = each.value.attach_cloud_sql && var.enable_cloud_sql ? [1] : []
        content {
          name       = "cloudsql"
          mount_path = "/cloudsql"
        }
      }
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "public" {
  for_each = local.public_services

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.services[each.value].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "invokers" {
  for_each = local.service_invokers

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.services[each.value.service].name
  role     = "roles/run.invoker"
  member   = each.value.member
}

resource "google_cloud_run_v2_service_iam_member" "iap_invoker" {
  for_each = local.iap_services

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.services[each.value].name
  role     = "roles/run.invoker"
  member   = local.iap_service_agent
}

resource "google_iap_web_cloud_run_service_iam_member" "iap_accessors" {
  for_each = local.iap_accessors

  project                = var.project_id
  location               = var.region
  cloud_run_service_name = google_cloud_run_v2_service.services[each.value.service].name
  role                   = "roles/iap.httpsResourceAccessor"
  member                 = each.value.member
}

#
# Cloud Run jobs
#
resource "google_cloud_run_v2_job" "jobs" {
  for_each = var.jobs

  project  = var.project_id
  name     = "${var.name}-${each.key}"
  location = var.region
  labels   = local.labels

  template {
    template {
      service_account = var.service_account_email

      dynamic "volumes" {
        for_each = each.value.mount_state && var.state_bucket_name != null ? [1] : []
        content {
          name = "runtime-state"
          gcs {
            bucket    = var.state_bucket_name
            read_only = false
          }
        }
      }

      dynamic "volumes" {
        for_each = each.value.attach_cloud_sql && var.enable_cloud_sql ? [1] : []
        content {
          name = "cloudsql"
          cloud_sql_instance {
            instances = [local.cloud_sql_connection_name]
          }
        }
      }

      containers {
        image = each.value.image

        dynamic "env" {
          for_each = merge(
            var.common_env,
            local.topic_env,
            each.value.attach_cloud_sql ? local.database_env : {},
            each.value.env
          )
          content {
            name  = env.key
            value = env.value
          }
        }

        dynamic "env" {
          for_each = merge(
            each.value.attach_cloud_sql ? local.database_secret_env : {},
            each.value.secret_env
          )
          content {
            name = env.key
            value_source {
              secret_key_ref {
                secret  = env.value
                version = "latest"
              }
            }
          }
        }

        dynamic "volume_mounts" {
          for_each = each.value.mount_state && var.state_bucket_name != null ? [1] : []
          content {
            name       = "runtime-state"
            mount_path = each.value.state_mount_path
          }
        }

        dynamic "volume_mounts" {
          for_each = each.value.attach_cloud_sql && var.enable_cloud_sql ? [1] : []
          content {
            name       = "cloudsql"
            mount_path = "/cloudsql"
          }
        }
      }
    }
  }
}

#
# Cloud Scheduler (authenticated HTTP calls to a service)
#
resource "google_cloud_run_v2_service_iam_member" "scheduler_invoker" {
  for_each = local.scheduler_targets

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.services[each.value].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.service_account_email}"
}

resource "google_cloud_scheduler_job" "jobs" {
  for_each = var.scheduler_jobs

  project     = var.project_id
  region      = var.region
  name        = "${var.name}-${each.key}"
  description = coalesce(each.value.description, "Soma scheduled call to ${each.value.target_service}${each.value.path}")
  schedule    = each.value.schedule
  time_zone   = each.value.time_zone

  http_target {
    uri         = "${google_cloud_run_v2_service.services[each.value.target_service].uri}${each.value.path}"
    http_method = each.value.http_method

    oidc_token {
      service_account_email = var.service_account_email
    }
  }

  depends_on = [google_cloud_run_v2_service_iam_member.scheduler_invoker]
}
