// The agape-app pattern: the standard Soma deployment for an Agape-powered
// application, extracted from league-analyzer's coach (the reference
// implementation).
//
//   ┌────────────────────┐        ┌──────────────────────┐
//   │  <name>-app        │        │  <name>-studio       │
//   │  the application   │        │  Agape Studio (admin)│
//   │  embeds agape-ts   │        │  editor · graph ·    │
//   │  runtime in-process│        │  ledger · providers  │
//   └────────┬───────────┘        └──────────┬───────────┘
//        IAP | provider secrets (Secret Manager) | IAP
//            └───────────────┬────────────────┘
//                            ▼
//            GCS state mount: <agape_mount_path>
//            programs · agape.toml · .agape/memory
//            (Studio edits are what the app executes)
//
// Cognition runs only inside the Agape programs; secrets are a deployment
// concern (Secret Manager -> env var, never a .env in cloud); the knowledge
// substrate persists across revisions. Pair with the app-side files in
// templates/agape-app/ (Dockerfile targets, entrypoint seeding, deploy script).

module "foundation" {
  source     = "../foundation"
  project_id = var.project_id
  region     = var.region
  name       = var.name
  labels     = var.labels

  # The pattern creates configurable provider secrets plus a stable Studio
  # access token (Studio mints a random one per boot otherwise). Apps add
  # their own via extra_secret_names.
  secret_names = concat(var.provider_secret_names, ["studio-access-token"], var.extra_secret_names)

  additional_gcp_services = concat(
    var.enable_cloud_sql ? ["sqladmin.googleapis.com"] : [],
    var.enable_iap ? ["iap.googleapis.com"] : [],
    var.additional_gcp_services,
  )

  runtime_roles = concat(
    ["roles/logging.logWriter"],
    var.enable_cloud_sql ? ["roles/cloudsql.client"] : [],
    var.extra_runtime_roles,
  )
}

module "runtime" {
  source                = "../runtime"
  project_id            = var.project_id
  region                = var.region
  name                  = var.name
  labels                = var.labels
  service_account_email = module.foundation.runtime_service_account
  state_bucket_name     = module.foundation.state_bucket_name

  enable_cloud_sql = var.enable_cloud_sql
  database_tier    = var.database_tier

  # Both services see the same persistent Agape project.
  common_env = {
    (var.agape_dir_env_var) = var.agape_mount_path
  }

  services = {
    app = {
      image            = var.app_image
      port             = var.app_port
      mount_state      = true
      attach_cloud_sql = var.enable_cloud_sql
      min_instances    = var.app_min_instances
      max_instances    = var.app_max_instances
      env              = var.app_env

      secret_env = merge(
        { for env_name, short in var.app_provider_secret_env : env_name => module.foundation.secret_ids[short] },
        { for env_name, short in var.app_secret_env : env_name => module.foundation.secret_ids[short] },
      )

      allow_unauthenticated = var.allow_unauthenticated
      invoker_members       = var.invoker_members
      enable_iap            = var.enable_iap
      iap_members           = var.iap_members
    }

    studio = {
      image       = var.studio_image
      port        = 8080
      mount_state = true
      # The lens, not the pen: Studio inspects the deployed project (programs,
      # ledger, memory) but cannot mutate it — deployed cognition changes only
      # by release. Set studio_readonly = false to restore live editing.
      mount_state_read_only = var.studio_readonly
      max_instances         = 1
      env                   = var.studio_env

      # IAP authenticates Studio; the token gate is opt-in defense-in-depth.
      secret_env = merge(
        { for env_name, short in var.studio_provider_secret_env : env_name => module.foundation.secret_ids[short] },
        var.studio_require_token ? { STUDIO_ACCESS_TOKEN = module.foundation.secret_ids["studio-access-token"] } : {},
      )

      enable_iap  = var.enable_iap
      iap_members = var.iap_members
    }
  }
}