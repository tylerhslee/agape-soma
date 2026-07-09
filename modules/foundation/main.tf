locals {
  labels = merge(var.labels, {
    app     = var.name
    layer   = "soma"
    managed = "terraform"
  })

  required_services = toset([
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudscheduler.googleapis.com",
    "firestore.googleapis.com",
    "iam.googleapis.com",
    "iap.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com"
  ])

  runtime_roles = toset([
    "roles/cloudsql.client",
    "roles/datastore.user",
    "roles/logging.logWriter",
    "roles/pubsub.publisher",
    "roles/pubsub.subscriber"
  ])

  secret_ids = {
    app_env         = "${var.name}-app-env"
    plaid_client_id = "${var.name}-plaid-client-id"
    plaid_secret    = "${var.name}-plaid-secret"
    openai_api_key  = "${var.name}-openai-api-key"
  }

  state_bucket_name = coalesce(var.state_bucket_name, "${var.project_id}-${var.name}-runtime-state")
}

resource "google_project_service" "services" {
  for_each = local.required_services

  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

data "google_project" "current" {
  project_id = var.project_id

  depends_on = [google_project_service.services]
}

# Fresh projects run Cloud Build as the compute default service account, which
# needs builder permissions (source download, image push, log writing) before
# `gcloud builds submit` can work.
resource "google_project_iam_member" "cloud_build_compute_builder" {
  project = var.project_id
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"

  depends_on = [google_project_service.services]
}

resource "google_artifact_registry_repository" "containers" {
  project       = var.project_id
  location      = var.region
  repository_id = "${var.name}-containers"
  format        = "DOCKER"
  labels        = local.labels

  depends_on = [google_project_service.services]
}

resource "google_service_account" "runtime" {
  project      = var.project_id
  account_id   = "${var.name}-runtime"
  display_name = "${var.name} Soma runtime"

  depends_on = [google_project_service.services]
}

resource "google_project_iam_member" "runtime_roles" {
  for_each = local.runtime_roles

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_secret_manager_secret" "secrets" {
  for_each = local.secret_ids

  project   = var.project_id
  secret_id = each.value

  replication {
    auto {}
  }

  labels     = local.labels
  depends_on = [google_project_service.services]
}

resource "google_secret_manager_secret_iam_member" "runtime_secret_access" {
  for_each = google_secret_manager_secret.secrets

  project   = var.project_id
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_storage_bucket" "runtime_state" {
  project  = var.project_id
  name     = local.state_bucket_name
  location = var.region

  uniform_bucket_level_access = true
  labels                      = local.labels

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age                = 30
      num_newer_versions = 5
      with_state         = "ARCHIVED"
    }

    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.services]
}

resource "google_storage_bucket_iam_member" "runtime_state_writer" {
  bucket = google_storage_bucket.runtime_state.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.runtime.email}"
}
