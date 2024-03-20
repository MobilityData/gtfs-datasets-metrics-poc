/**
 * MobilityData 2023
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

provider "google" {
  project = var.project_id
  region =  var.gcp_region
}

resource "google_project_service" "workflows" {
  service            = "workflows.googleapis.com"
  disable_on_destroy = false
}

resource "google_service_account" "containers_service_account" {
  account_id   = "containers-sa"
  display_name = "Containers Service Account"
}

resource "google_project_iam_member" "log_binding" {
  project = var.project_id
  role    = "roles/logging.logWriter" #logging.logEntries.create
  member  = "serviceAccount:${google_service_account.containers_service_account.email}"
}

resource "google_project_iam_member" "run_admin_binding" {
  project = var.project_id
  role    = "roles/run.admin" #run.jobs.create
  member  = "serviceAccount:${google_service_account.containers_service_account.email}"
}

resource "google_project_iam_member" "service_user_binding" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser" #iam.serviceAccounts.actAs
  member  = "serviceAccount:${google_service_account.containers_service_account.email}"
}

resource "google_storage_bucket" "mobilitydata-gtfs-validation-results" {
  name          = "mobilitydata-gtfs-validation-results3"
  location      = "US"
  force_destroy = true

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
}

resource "google_storage_bucket_iam_member" "bucket_member" {
  bucket = google_storage_bucket.mobilitydata-gtfs-validation-results.name
  role   = "roles/storage.objectAdmin"

  member = "serviceAccount:${google_service_account.containers_service_account.email}"
}

resource "google_artifact_registry_repository" "gtfs-validator-registry" {
  location      = "us-central1"
  repository_id = "gtfs-validator-registry"
  description   = "GTFS Validator Docker Registry"
  format        = "DOCKER"

#   docker_config {
#     immutable_tags = true
#   }
}

resource "google_workflows_workflow" "workflow-gtfs-validator" {
  name            = "workflow-gtfs-validator3"
  region          = var.gcp_region
  description     = "GTFS Validator Workflow"
  service_account = google_service_account.containers_service_account.id
  source_contents = file("./workflow-gtfs-validator.yaml")
  depends_on      = [google_project_service.workflows]
}

resource "google_storage_bucket" "functionBucket" {
  name     = "${var.project_id}-function"
  location = var.gcp_region
}

data "archive_file" "source" {
  type        = "zip"
  source_dir  = "./functions/get-gtfs-catalog"
  output_path = "./tmp/get-gtfs-catalog.zip"
}

# Add source code zip to the Cloud Function's bucket
resource "google_storage_bucket_object" "archive" {
  source       = data.archive_file.source.output_path
  content_type = "application/zip"

  # Append to the MD5 checksum of the files's content
  # to force the zip to be updated as soon as a change occurs
  name   = "src-${data.archive_file.source.output_md5}.zip"
  bucket = google_storage_bucket.functionBucket.name

  # Dependencies are automatically inferred so these lines can be deleted
  depends_on = [
    google_storage_bucket.functionBucket, # declared in `storage.tf`
    data.archive_file.source
  ]
}

resource "google_cloudfunctions_function" "getGtfsCatalogFunction" {
  name        = "get-gtfs-catalog"
  description = "get-gtfs-catalog"
  runtime     = "python39"

  available_memory_mb   = 256
  source_archive_bucket = google_storage_bucket.functionBucket.name
  source_archive_object = google_storage_bucket_object.archive.name
  trigger_http          = true
  entry_point           = "get_request"

  https_trigger_security_level = "SECURE_ALWAYS"
  timeout                      = 120
  labels = {
    group = "gtfs-validator-metrics"
  }

}

resource "google_cloudfunctions_function_iam_member" "invoker" {
  project        = google_cloudfunctions_function.getGtfsCatalogFunction.project
  region         = google_cloudfunctions_function.getGtfsCatalogFunction.region
  cloud_function = google_cloudfunctions_function.getGtfsCatalogFunction.name

  role   = "roles/cloudfunctions.invoker"
  member  = "serviceAccount:${google_service_account.containers_service_account.email}"
}

resource "google_workflows_workflow" "workflow-gtfs-catalog-validator" {
  name            = "workflow-gtfs-catalog-validator3"
  region          = var.gcp_region
  description     = "GTFS Catalog Validator Workflow"
  service_account = google_service_account.containers_service_account.id
  source_contents = templatefile("./workflow-gtfs-catalog-validator.yaml", { "configCatalogFunctionUrl" = "${google_cloudfunctions_function.getGtfsCatalogFunction.https_trigger_url}"})
  depends_on = [google_project_service.workflows, google_cloudfunctions_function.getGtfsCatalogFunction]
}

resource "google_project_iam_member" "workflow_executor_binding" {
  project = var.project_id
  role    = "roles/workflows.invoker" #workflows.executions.create
  member  = "serviceAccount:${google_service_account.containers_service_account.email}"
}

## Big Query

resource "google_bigquery_dataset" "gtfs-results-dataset" {
  dataset_id                  = var.gtfs_results_dataset_id
  friendly_name               = "gtfs_results"
  description                 = "GTFS Validation Results Dataset"
  location                    = var.gtfs_results_dataset_location
  #default_table_expiration_ms = 3600000
}

resource "google_bigquery_table" "validation_results_table" {
  dataset_id = var.gtfs_results_dataset_id
  table_id = var.gtfs_results_dataset_table_id

   schema = "${file("./validation-result-schema.json")}"

   depends_on = [ google_bigquery_dataset.gtfs-results-dataset ]
}