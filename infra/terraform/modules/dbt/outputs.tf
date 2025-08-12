output "dbt_project_path" {
  description = "Путь к dbt проекту"
  value       = var.dbt_base_path
}

output "dbt_environment_path" {
  description = "Путь к виртуальному окружению dbt"
  value       = "${var.dbt_base_path}/dbt_env"
}

output "dbt_python_path" {
  description = "Путь к Python интерпретатору dbt"
  value       = "${var.dbt_base_path}/dbt_env/bin/python"
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

output "dbt_versions" {
  description = "Версии dbt компонентов"
  value = {
    dbt_core     = var.dbt_core_version
    dbt_clickhouse = var.dbt_version
  }
}

output "dbt_activation_script" {
  description = "Путь к скрипту активации dbt окружения"
  value       = "${var.dbt_base_path}/activate_dbt.sh"
}
