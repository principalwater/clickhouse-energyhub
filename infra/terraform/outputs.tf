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

  3. Connect using the clickhouse-client or any HTTP client (use the 'clickhouse_user' and 'clickhouse_password' you defined in your variables):
     clickhouse-client --host localhost --port 8123 --user <your_user> --password <your_password>
  EOT
}

output "clickhouse_pod_access" {
  description = "How to get a shell inside a ClickHouse pod (equivalent to 'docker exec')."
  value       = <<-EOT
  To run 'clickhouse-client' directly inside the running container (the Kubernetes way):
  
  1. Find the pod name. It will look like 'chi-energyhub-cluster-dwh-prod-0-0-0'.
     kubectl get pods -n ${var.k8s_namespace}

  2. Use 'kubectl exec' to get an interactive shell inside the pod:
     kubectl exec -it <pod-name-from-step-1> -n ${var.k8s_namespace} -- /bin/sh

  3. Once inside the pod, you can use the client (use the 'clickhouse_user' and 'clickhouse_password' you defined in your variables):
     clickhouse-client --user <your_user> --password <your_password>
  EOT
}
