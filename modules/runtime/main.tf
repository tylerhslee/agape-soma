data "google_project" "current" {
  project_id = var.project_id
}

locals {
  labels = merge(var.labels, {
    app     = var.name
    layer   = "soma-runtime"
    managed = "terraform"
  })

  signal_topics = toset([
    "sensory-events",
    "transaction-observed",
    "classification-requested",
    "decision-events",
    "ledger-events"
  ])

  cloud_sql_connection_name = var.enable_cloud_sql ? google_sql_database_instance.postgres[0].connection_name : null

  database_env = var.enable_cloud_sql ? {
    PGDATABASE          = var.database_name
    PGHOST              = "/cloudsql/${local.cloud_sql_connection_name}"
    PGUSER              = var.database_user
    WHALE_STATE_BACKEND = "postgres"
  } : {}

  database_secret_env = var.enable_cloud_sql ? {
    PGPASSWORD = google_secret_manager_secret.database_password[0].secret_id
  } : {}

  runtime_secret_env = merge(var.secret_env, local.database_secret_env)

  base_env = {
    AGAPE_BIN                       = "/usr/local/bin/agape"
    PLAID_ENV                       = var.plaid_env
    SOMA_CLASSIFICATION_TOPIC       = google_pubsub_topic.signals["classification-requested"].id
    SOMA_DECISION_TOPIC             = google_pubsub_topic.signals["decision-events"].id
    SOMA_LEDGER_TOPIC               = google_pubsub_topic.signals["ledger-events"].id
    SOMA_SENSORY_TOPIC              = google_pubsub_topic.signals["sensory-events"].id
    SOMA_TRANSACTION_OBSERVED_TOPIC = google_pubsub_topic.signals["transaction-observed"].id
    WHALE_DATA_DIR                  = "/data"
    WHALE_STATE_PATH                = "/data/whale-state.json"
  }

  api_env = merge(local.base_env, local.database_env, var.common_env, var.api_env, {
    API_PORT          = "8787"
    SOMA_SERVICE_ROLE = "sensory-gateway"
  })

  sync_worker_env = merge(local.base_env, local.database_env, var.common_env, var.worker_env, {
    SOMA_SERVICE_ROLE = "sensor-sync"
    WHALE_WORKER_MODE = "sync-only"
  })

  classifier_worker_env = merge(local.base_env, local.database_env, var.common_env, var.worker_env, {
    SOMA_SERVICE_ROLE = "classifier-agent"
    WHALE_WORKER_MODE = "classify"
  })

  ui_env = merge(var.common_env, var.ui_env, {
    API_BASE_URL      = google_cloud_run_v2_service.api.uri
    SOMA_RUNTIME_NAME = var.name
    SOMA_SERVICE_ROLE = "whale-ui-gateway"
  })

  iap_service_agent = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-iap.iam.gserviceaccount.com"
}

resource "google_pubsub_topic" "signals" {
  for_each = local.signal_topics

  project = var.project_id
  name    = "${var.name}-${each.key}"
  labels  = local.labels
}

resource "google_pubsub_subscription" "classifier_requests" {
  project = var.project_id
  name    = "${var.name}-classifier-requests"
  topic   = google_pubsub_topic.signals["classification-requested"].id
  labels  = local.labels
}

resource "google_pubsub_subscription" "ledger_events" {
  project = var.project_id
  name    = "${var.name}-ledger-events"
  topic   = google_pubsub_topic.signals["ledger-events"].id
  labels  = local.labels
}

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

resource "google_cloud_run_v2_service" "api" {
  project  = var.project_id
  name     = "${var.name}-api"
  location = var.region
  ingress  = var.api_ingress
  labels   = local.labels

  template {
    service_account = var.service_account_email

    scaling {
      min_instance_count = var.api_min_instances
      max_instance_count = var.api_max_instances
    }

    volumes {
      name = "runtime-state"
      gcs {
        bucket    = var.state_bucket_name
        read_only = false
      }
    }

    dynamic "volumes" {
      for_each = var.enable_cloud_sql ? [1] : []
      content {
        name = "cloudsql"
        cloud_sql_instance {
          instances = [local.cloud_sql_connection_name]
        }
      }
    }

    containers {
      image = var.api_image

      ports {
        container_port = 8787
      }

      resources {
        limits = {
          cpu    = var.api_cpu
          memory = var.api_memory
        }
      }

      dynamic "env" {
        for_each = local.api_env
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = local.runtime_secret_env
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

      volume_mounts {
        name       = "runtime-state"
        mount_path = "/data"
      }

      dynamic "volume_mounts" {
        for_each = var.enable_cloud_sql ? [1] : []
        content {
          name       = "cloudsql"
          mount_path = "/cloudsql"
        }
      }
    }
  }
}

resource "google_cloud_run_v2_service" "ui" {
  project     = var.project_id
  name        = "${var.name}-ui"
  location    = var.region
  ingress     = var.ui_ingress
  iap_enabled = var.enable_iap_ui
  labels      = local.labels

  template {
    service_account = var.service_account_email

    scaling {
      min_instance_count = var.ui_min_instances
      max_instance_count = var.ui_max_instances
    }

    containers {
      image = var.ui_image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = var.ui_cpu
          memory = var.ui_memory
        }
      }

      dynamic "env" {
        for_each = local.ui_env
        content {
          name  = env.key
          value = env.value
        }
      }
    }
  }
}

resource "google_iap_web_cloud_run_service_iam_member" "ui_iap_accessors" {
  for_each = var.enable_iap_ui ? toset(var.iap_access_members) : []

  project                = var.project_id
  location               = var.region
  cloud_run_service_name = google_cloud_run_v2_service.ui.name
  role                   = "roles/iap.httpsResourceAccessor"
  member                 = each.value
}

resource "google_cloud_run_v2_service_iam_member" "ui_iap_invoker" {
  count = var.enable_iap_ui ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.ui.name
  role     = "roles/run.invoker"
  member   = local.iap_service_agent
}

resource "google_cloud_run_v2_service" "studio" {
  count = var.studio_image == null ? 0 : 1

  project  = var.project_id
  name     = "${var.name}-studio"
  location = var.region
  ingress  = var.studio_ingress
  labels   = local.labels

  template {
    service_account = var.service_account_email

    scaling {
      min_instance_count = var.studio_min_instances
      max_instance_count = var.studio_max_instances
    }

    volumes {
      name = "runtime-state"
      gcs {
        bucket    = var.state_bucket_name
        read_only = false
      }
    }

    containers {
      image = var.studio_image

      ports {
        container_port = var.studio_port
      }

      dynamic "env" {
        for_each = merge(local.base_env, var.common_env, var.studio_env, {
          API_BASE_URL      = google_cloud_run_v2_service.api.uri
          SOMA_SERVICE_ROLE = "agape-studio"
          WHALE_DATA_DIR    = "/data"
        })
        content {
          name  = env.key
          value = env.value
        }
      }

      volume_mounts {
        name       = "runtime-state"
        mount_path = "/data"
      }
    }
  }
}

resource "google_cloud_run_v2_job" "sensor_sync" {
  project  = var.project_id
  name     = "${var.name}-sensor-sync"
  location = var.region
  labels   = local.labels

  template {
    template {
      service_account = var.service_account_email

      dynamic "volumes" {
        for_each = var.enable_cloud_sql ? [1] : []
        content {
          name = "cloudsql"
          cloud_sql_instance {
            instances = [local.cloud_sql_connection_name]
          }
        }
      }

      containers {
        image = var.worker_image

        dynamic "env" {
          for_each = local.sync_worker_env
          content {
            name  = env.key
            value = env.value
          }
        }

        dynamic "env" {
          for_each = local.runtime_secret_env
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
          for_each = var.enable_cloud_sql ? [1] : []
          content {
            name       = "cloudsql"
            mount_path = "/cloudsql"
          }
        }
      }
    }
  }
}

resource "google_cloud_run_v2_job" "classifier_agent" {
  project  = var.project_id
  name     = "${var.name}-classifier-agent"
  location = var.region
  labels   = local.labels

  template {
    template {
      service_account = var.service_account_email

      dynamic "volumes" {
        for_each = var.enable_cloud_sql ? [1] : []
        content {
          name = "cloudsql"
          cloud_sql_instance {
            instances = [local.cloud_sql_connection_name]
          }
        }
      }

      containers {
        image = var.worker_image

        dynamic "env" {
          for_each = local.classifier_worker_env
          content {
            name  = env.key
            value = env.value
          }
        }

        dynamic "env" {
          for_each = local.runtime_secret_env
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
          for_each = var.enable_cloud_sql ? [1] : []
          content {
            name       = "cloudsql"
            mount_path = "/cloudsql"
          }
        }
      }
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "public_api" {
  count = var.allow_unauthenticated_api ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "public_ui" {
  count = var.allow_unauthenticated_ui ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.ui.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "public_studio" {
  count = var.studio_image != null && var.allow_unauthenticated_studio ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.studio[0].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "api_invokers" {
  for_each = toset(var.invoker_members)

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  member   = each.value
}

resource "google_cloud_run_v2_service_iam_member" "ui_invokers" {
  for_each = toset(var.invoker_members)

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.ui.name
  role     = "roles/run.invoker"
  member   = each.value
}

resource "google_cloud_run_v2_service_iam_member" "studio_invokers" {
  for_each = toset(var.studio_image == null ? [] : var.invoker_members)

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.studio[0].name
  role     = "roles/run.invoker"
  member   = each.value
}

resource "google_cloud_run_v2_service_iam_member" "api_scheduler_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.service_account_email}"
}

resource "google_cloud_scheduler_job" "transaction_sync" {
  project     = var.project_id
  region      = var.region
  name        = "${var.name}-transaction-sync"
  description = "Soma sensory tick: pull Plaid transactions and run the classifier path."
  schedule    = var.sync_schedule
  time_zone   = var.sync_time_zone

  http_target {
    uri         = "${google_cloud_run_v2_service.api.uri}/plaid/sync"
    http_method = "POST"

    oidc_token {
      service_account_email = var.service_account_email
    }
  }

  depends_on = [google_cloud_run_v2_service_iam_member.api_scheduler_invoker]
}
