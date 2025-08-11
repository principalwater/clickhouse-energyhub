output "metabase_url" {
  value = "http://localhost:${var.metabase_port}"
}

output "metabase_db_creds" {
  value = {
    user = var.metabase_pg_user
    db   = var.metabase_pg_db
    pass = var.metabase_pg_password
    host = "localhost"
    port = 5432
  }
  sensitive = true
}

output "superset_url" {
  value = "http://localhost:${var.superset_port}"
}

output "superset_db_creds" {
  value = {
    user = var.superset_pg_user
    db   = var.superset_pg_db
    pass = var.superset_pg_password
    host = "localhost"
    port = 5432
  }
  sensitive = true
}

output "postgres_container_name" {
  description = "Имя контейнера PostgreSQL."
  value       = local.any_bi_tool_enabled ? docker_container.postgres[0].name : null
}

output "postgres_network_name" {
  description = "Имя Docker-сети PostgreSQL."
  value       = local.any_bi_tool_enabled ? docker_network.metanet1[0].name : null
}

output "postgres_host" {
  description = "Хост PostgreSQL для подключения."
  value       = local.any_bi_tool_enabled ? "postgres" : null
}

output "postgres_port" {
  description = "Порт PostgreSQL."
  value       = 5432
}

output "postgres_superuser" {
  description = "Имя суперпользователя PostgreSQL."
  value       = "postgres"
}