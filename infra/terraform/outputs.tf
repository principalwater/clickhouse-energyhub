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

output "dbt_info" {
  description = "Информация о dbt модуле"
  value = var.deploy_dbt ? {
    project_path          = module.dbt[0].dbt_project_path
    environment_path      = module.dbt[0].dbt_environment_path
    python_path           = module.dbt[0].dbt_python_path
    profiles_path         = module.dbt[0].dbt_profiles_path
    clickhouse_connection = module.dbt[0].dbt_clickhouse_connection
    clickhouse_database   = module.dbt[0].clickhouse_database_info
    versions              = module.dbt[0].dbt_versions
    activation_script     = module.dbt[0].dbt_activation_script
  } : null
}
