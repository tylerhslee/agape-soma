locals {
  labels = merge(var.labels, {
    app     = var.name
    layer   = "soma"
    managed = "terraform"
  })

  # Base APIs the foundation itself needs. App-specific APIs (pubsub, sqladmin,
  # cloudscheduler, iap, firestore, ...) are opt-in via var.additional_gcp_services.
  base_services = [
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "iam.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "storage.googleapis.com",
  ]

  required_services = toset(concat(local.base_services, var.additional_gcp_services))

  runtime_roles = toset(var.runtime_roles)

  # secret short-name => full secret id
  secret_ids = { for short in var.secret_names : short => "${var.name}-${short}" }

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
  count = var.grant_cloudbuild_builder ? 1 : 0

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
  count = var.enable_state_bucket ? 1 : 0

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
  count = var.enable_state_bucket ? 1 : 0

  bucket = google_storage_bucket.runtime_state[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.runtime.email}"
}
