###############################################################################
# Root Terraform file for deploying the ClickHouse EnergyHub
###############################################################################

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.6.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "6.4.0"
    }
  }
}

# --- Providers ---
# Note: Providers are defined in the root and passed down to modules implicitly.
provider "docker" {}

provider "docker" {
  alias = "remote_host"
  host  = "ssh://${var.remote_ssh_user}@${var.remote_host_name}"
}

provider "aws" {
  alias      = "remote_backup"
  access_key = var.minio_root_user
  secret_key = var.minio_root_password
  region     = "us-east-1"
  endpoints {
    s3 = "http://${var.remote_host_name}:${var.remote_minio_port}"
  }
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

provider "aws" {
  alias      = "local_storage"
  access_key = var.minio_root_user
  secret_key = var.minio_root_password
  region     = "us-east-1"
  endpoints {
    s3 = "http://localhost:${var.local_minio_port}"
  }
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

# --- Modules ---

module "clickhouse_cluster" {
  source = "./modules/clickhouse-cluster"

  providers = {
    docker.remote_host = docker.remote_host
    aws.remote_backup  = aws.remote_backup
    aws.local_storage  = aws.local_storage
  }

  # Pass all necessary variables to the module
  clickhouse_base_path    = var.clickhouse_base_path
  memory_limit            = var.memory_limit
  super_user_name         = var.super_user_name
  bi_user_name            = var.bi_user_name
  super_user_password     = var.super_user_password
  bi_user_password        = var.bi_user_password
  ch_version              = var.ch_version
  chk_version             = var.chk_version
  minio_version           = var.minio_version
  ch_uid                  = var.ch_uid
  ch_gid                  = var.ch_gid
  use_standard_ports      = var.use_standard_ports
  ch_http_port            = var.ch_http_port
  ch_tcp_port             = var.ch_tcp_port
  ch_replication_port     = var.ch_replication_port
  minio_root_user         = var.minio_root_user
  minio_root_password     = var.minio_root_password
  remote_ssh_user         = var.remote_ssh_user
  ssh_private_key_path    = var.ssh_private_key_path
  local_minio_port        = var.local_minio_port
  remote_minio_port       = var.remote_minio_port
  storage_type            = var.storage_type
  local_minio_path        = var.local_minio_path
  remote_minio_path       = var.remote_minio_path
  local_backup_minio_path = var.local_backup_minio_path
  remote_host_name        = var.remote_host_name
  bucket_backup           = var.bucket_backup
  bucket_storage          = var.bucket_storage
  local_backup_minio_port = var.local_backup_minio_port
}
