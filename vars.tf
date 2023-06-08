variable "project_id" {
  type = string
  description = "GCP project ID"
}

variable "gcp_region" {
  type = string
  description = "GCP region"
}

variable "gtfs_results_dataset_id" {
  type = string
  description = "GTFS BigQuery table Id"
  default = "gtfs_results_dataset"
}

variable "gtfs_results_dataset_location" {
  type = string
  description = "GTFS BigQuery table location"
  default = "US"
}

variable "gtfs_results_dataset_table_id" {
  type = string
  description = "GTFS BigQuery table location"
  default = "gtfs_results"
}
