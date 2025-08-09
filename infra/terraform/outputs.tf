# --- Вывод информации о развернутой инфраструктуре ---

output "deployment_summary" {
  description = "Сводная информация о развернутой конфигурации"
  value = {
    "storage_mode"              = var.storage_type == "local_ssd" ? "Локальное хранилище на хосте" : "S3-хранилище на внешнем SSD"
    "clickhouse_http_endpoint"  = "http://localhost:${var.use_standard_ports ? var.ch_http_port : local.clickhouse_nodes[0].http_port}"
    "clickhouse_tcp_endpoint"   = "tcp://localhost:${var.use_standard_ports ? var.ch_tcp_port : local.clickhouse_nodes[0].tcp_port}"
    "local_minio_s3_endpoint"   = var.storage_type == "s3_ssd" ? "http://localhost:${var.local_minio_port}" : "Не используется"
    "local_minio_console"       = var.storage_type == "s3_ssd" ? "http://localhost:${var.local_minio_port + 1}" : "Не используется"
    "remote_backup_s3_endpoint" = "http://${var.remote_host_name}:${var.remote_minio_port}"
    "remote_backup_console"     = "http://${var.remote_host_name}:${var.remote_minio_port + 1}"
  }
}

output "clickhouse_nodes_info" {
  description = "Информация о нодах ClickHouse"
  value = { for node in local.clickhouse_nodes : node.name => {
    shard     = node.shard
    replica   = node.replica
    host      = node.host
    http_port = node.http_port
    tcp_port  = node.tcp_port
  } }
}

output "keeper_nodes_info" {
  description = "Информация о нодах ClickHouse Keeper"
  value = { for node in local.keeper_nodes : node.name => {
    id       = node.id
    host     = node.host
    tcp_port = node.tcp_port
  } }
}
