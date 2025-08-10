output "deployment_summary" {
  description = "Сводная информация о развернутой конфигурации"
  value       = module.clickhouse_cluster.deployment_summary
}

output "clickhouse_nodes_info" {
  description = "Информация о нодах ClickHouse"
  value       = module.clickhouse_cluster.clickhouse_nodes_info
}

output "keeper_nodes_info" {
  description = "Информация о нодах ClickHouse Keeper"
  value       = module.clickhouse_cluster.keeper_nodes_info
}
