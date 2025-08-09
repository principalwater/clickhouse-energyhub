# ------------------------------------------------------------------------------
# General Project & K8s Variables
# ------------------------------------------------------------------------------
variable "project_name" {
  description = "A name for the project to prefix resources."
  type        = string
  default     = "energyhub"
}

variable "k8s_namespace" {
  description = "Kubernetes namespace to deploy all resources into."
  type        = string
  default     = "energyhub"
}

# ------------------------------------------------------------------------------
# Service Versions (Matching reference project)
# ------------------------------------------------------------------------------
variable "clickhouse_operator_version" {
  description = "Version of the Altinity ClickHouse Operator Helm chart."
  type        = string
  default     = "0.25.3"
}

variable "clickhouse_image" {
  description = "The full Docker image for ClickHouse server to be deployed by the operator."
  type        = string
  default     = "clickhouse/clickhouse-server:25.5.2-alpine"
}

variable "minio_version" {
  description = "Version of MinIO to use for S3-compatible storage."
  type        = string
  default     = "RELEASE.2025-07-23T15-54-02Z"
}

# ------------------------------------------------------------------------------
# Host and Path Configuration
# These paths must be absolute and exist on the respective machines.
# ------------------------------------------------------------------------------
variable "local_ssd_data_path" {
  description = "Absolute path on the main host (Mac Studio) to store ClickHouse data volumes. This directory will be mounted into the Kubernetes cluster."
  type        = string
}

variable "use_remote_backup_host" {
  description = "Set to true to use a remote machine for backups. If false, MinIO will be run locally on the main host."
  type        = bool
  default     = true
}

variable "remote_backup_host" {
  description = "Hostname or IP address of the remote backup server (e.g., Raspberry Pi). Only used if use_remote_backup_host is true."
  type        = string
  default     = "water-rpi.local"
}

variable "remote_ssh_user" {
  description = "SSH user for connecting to the remote backup host. Ensure SSH keys are configured."
  type        = string
}

variable "remote_backup_path" {
  description = "Absolute path on the remote host to store MinIO backup data. Only used if use_remote_backup_host is true."
  type        = string
}

variable "local_backup_path" {
  description = "Absolute path on the main host to store MinIO backup data. Only used if use_remote_backup_host is false."
  type        = string
  default     = "" # Must be provided by user if use_remote_backup_host is false
}

# ------------------------------------------------------------------------------
# S3/MinIO & ClickHouse Credentials
# It's highly recommended to populate these via a terraform.tfvars.json file or environment variables.
# ------------------------------------------------------------------------------
variable "minio_root_user" {
  description = "Root username for MinIO."
  type        = string
  sensitive   = true
}

variable "minio_root_password" {
  description = "Root password for MinIO."
  type        = string
  sensitive   = true
}

variable "clickhouse_user" {
  description = "Default admin user for the ClickHouse cluster."
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "clickhouse_password" {
  description = "Password for the ClickHouse admin user."
  type        = string
  sensitive   = true
}

# ------------------------------------------------------------------------------
# S3/MinIO Network & Bucket Configuration
# ------------------------------------------------------------------------------
variable "minio_api_port" {
  description = "API port for the MinIO container."
  type        = number
  default     = 9000
}

variable "minio_console_port" {
  description = "Web console port for the MinIO container."
  type        = number
  default     = 9001
}

variable "s3_backup_bucket" {
  description = "Name of the S3 bucket to create for backups."
  type        = string
  default     = "clickhouse-backups"
}
