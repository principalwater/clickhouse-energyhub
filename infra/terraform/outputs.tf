# ------------------------------------------------------------------------------
# Terraform Outputs
# ------------------------------------------------------------------------------

output "kubernetes_namespace" {
  description = "The Kubernetes namespace where all resources were deployed."
  value       = kubernetes_namespace.energyhub_ns.metadata[0].name
}

output "minio_backup_console_url" {
  description = "URL for the MinIO backup web console."
  value       = "http://${local.backup_host}:${var.minio_console_port}"
}

output "minio_credentials" {
  description = "Credentials for the MinIO backup service."
  value = {
    user      = var.minio_root_user
    password  = var.minio_root_password
    endpoint  = "http://${local.backup_host}:${var.minio_api_port}"
    bucket    = var.s3_backup_bucket
  }
  sensitive = true
}

output "clickhouse_connection_info" {
  description = "Instructions on how to connect to the ClickHouse cluster."
  value       = <<-EOT
  To connect to the ClickHouse cluster, you first need to expose the service from Kubernetes.
  The service name is 'chi-energyhub-cluster-energy-cluster-0-0' (or similar).
  
  1. Find the service name:
     kubectl get services -n ${var.k8s_namespace}

  2. Port-forward the service to your local machine:
     kubectl port-forward svc/<service-name-from-step-1> 8123:8123 -n ${var.k8s_namespace}

  3. Connect using the clickhouse-client or any HTTP client:
     clickhouse-client --host localhost --port 8123 --user ${var.clickhouse_user} --password <your_password>
  EOT
}
