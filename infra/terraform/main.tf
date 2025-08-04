################################################################################
# Terraform Configuration for Local ClickHouse on Kubernetes
# Target: Local K8s (Kind, Docker Desktop) on Mac Studio
# Backup: S3-compatible (MinIO) on a remote or local host
################################################################################

terraform {
  required_version = ">= 1.2"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.30.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.13.2"
    }
  }
}

# --- Locals ---
locals {
  # Determine the backup host and path based on the toggle
  backup_host      = var.use_remote_backup_host ? var.remote_backup_host : "localhost"
  backup_data_path = var.use_remote_backup_host ? var.remote_backup_path : var.local_backup_path

  # Determine the correct docker provider alias
  backup_provider_alias = var.use_remote_backup_host ? "remote" : "local"
}


# --- Provider Configuration ---

# Docker provider for local host (Mac Studio)
provider "docker" {
  alias = "local"
}

# Docker provider for the remote backup host (Raspberry Pi)
# This provider is only configured if remote backups are enabled.
provider "docker" {
  alias = "remote"
  host  = var.use_remote_backup_host ? "ssh://${var.remote_ssh_user}@${var.remote_backup_host}" : null
}

# Kubernetes provider targeting the local k8s cluster
provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

# --- Resources ---

# MinIO container for backups, created on the REMOTE host.
resource "docker_container" "minio_backup_remote" {
  count    = var.use_remote_backup_host ? 1 : 0
  provider = docker.remote

  name    = "minio-backup-storage"
  image   = "minio/minio:${var.minio_version}"
  restart = "always"

  ports {
    internal = 9000
    external = var.minio_api_port
  }
  ports {
    internal = 9001
    external = var.minio_console_port
  }

  mounts {
    source = local.backup_data_path
    target = "/data"
    type   = "bind"
  }

  env = [
    "MINIO_ROOT_USER=${var.minio_root_user}",
    "MINIO_ROOT_PASSWORD=${var.minio_root_password}",
    "MINIO_DEFAULT_BUCKETS=${var.s3_backup_bucket}"
  ]
  command = ["server", "/data", "--console-address", ":9001"]
}

# MinIO container for backups, created on the LOCAL host.
resource "docker_container" "minio_backup_local" {
  count    = var.use_remote_backup_host ? 0 : 1
  provider = docker.local

  name    = "minio-backup-storage"
  image   = "minio/minio:${var.minio_version}"
  restart = "always"

  ports {
    internal = 9000
    external = var.minio_api_port
  }
  ports {
    internal = 9001
    external = var.minio_console_port
  }

  mounts {
    source = local.backup_data_path
    target = "/data"
    type   = "bind"
  }

  env = [
    "MINIO_ROOT_USER=${var.minio_root_user}",
    "MINIO_ROOT_PASSWORD=${var.minio_root_password}",
    "MINIO_DEFAULT_BUCKETS=${var.s3_backup_bucket}"
  ]
  command = ["server", "/data", "--console-address", ":9001"]
}

# Namespace for the energyhub project
resource "kubernetes_namespace" "energyhub_ns" {
  metadata {
    name = var.k8s_namespace
  }
}

# Secret for S3 backup credentials
resource "kubernetes_secret" "s3_credentials" {
  metadata {
    name      = "ch-s3-credentials"
    namespace = kubernetes_namespace.energyhub_ns.metadata[0].name
  }
  data = {
    "accessKeyId"     = var.minio_root_user
    "secretAccessKey" = var.minio_root_password
  }
  type = "Opaque"
}

# Deploy ClickHouse Operator using Helm
resource "helm_release" "clickhouse_operator" {
  name       = "clickhouse-operator"
  repository = "https://altinity.github.io/clickhouse-operator"
  chart      = "clickhouse-operator"
  version    = var.clickhouse_operator_version
  namespace  = kubernetes_namespace.energyhub_ns.metadata[0].name

  set {
    name  = "metrics.enabled"
    value = "true"
  }

  depends_on = [kubernetes_namespace.energyhub_ns]
}

# Deploy ClickHouse Cluster using the Operator's Custom Resource
resource "kubernetes_manifest" "clickhouse_cluster" {
  manifest = yamldecode(templatefile("${path.module}/manifests/clickhouse-installation.yaml.tpl", {
    k8s_namespace       = kubernetes_namespace.energyhub_ns.metadata[0].name
    s3_backup_endpoint  = "http://${local.backup_host}:${var.minio_api_port}"
    s3_backup_bucket    = var.s3_backup_bucket
    s3_secret_name      = kubernetes_secret.s3_credentials.metadata[0].name
    clickhouse_image    = var.clickhouse_image
    clickhouse_user     = var.clickhouse_user
    clickhouse_password = var.clickhouse_password
    local_ssd_data_path = var.local_ssd_data_path
  }))

  depends_on = [
    helm_release.clickhouse_operator,
    kubernetes_secret.s3_credentials,
    docker_container.minio_backup_remote,
    docker_container.minio_backup_local
  ]
}
