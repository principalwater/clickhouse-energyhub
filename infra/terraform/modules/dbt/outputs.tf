output "dbt_project_path" {
  description = "Путь к dbt проекту"
  value       = var.dbt_base_path
}

output "dbt_container_name" {
  description = "Имя контейнера dbt"
  value       = docker_container.dbt_clickhouse.name
}

output "dbt_container_id" {
  description = "ID контейнера dbt"
  value       = docker_container.dbt_clickhouse.id
}

output "dbt_profiles_path" {
  description = "Путь к профилям dbt"
  value       = local.dbt_profiles_path
}

output "dbt_clickhouse_connection" {
  description = "Параметры подключения dbt к ClickHouse"
  value = {
    host     = var.clickhouse_host
    port     = var.clickhouse_port
    database = var.clickhouse_database
    user     = var.clickhouse_user
  }
  sensitive = false
}
