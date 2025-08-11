# --------------------------------------------------------------------------------------------------
# OUTPUTS для модуля PostgreSQL
# --------------------------------------------------------------------------------------------------

output "postgres_container_name" {
  description = "Имя контейнера PostgreSQL."
  value       = var.enable_postgres ? docker_container.postgres[0].name : null
}

output "postgres_network_name" {
  description = "Имя Docker-сети PostgreSQL."
  value       = var.enable_postgres ? docker_network.postgres_network[0].name : null
}

output "postgres_host" {
  description = "Хост PostgreSQL для подключения."
  value       = var.enable_postgres ? "postgres" : null
}

output "postgres_port" {
  description = "Порт PostgreSQL."
  value       = 5432
}

output "postgres_superuser" {
  description = "Имя суперпользователя PostgreSQL."
  value       = "postgres"
}

output "postgres_connection_string" {
  description = "Строка подключения к PostgreSQL для суперпользователя."
  value       = var.enable_postgres ? "postgresql://postgres:${var.postgres_superuser_password}@postgres:5432/postgres" : null
  sensitive   = true
}

# ---- Section: Metabase outputs ----
output "metabase_db_connection_string" {
  description = "Строка подключения к базе данных Metabase."
  value       = var.enable_postgres && var.enable_metabase ? "postgresql://${var.metabase_pg_user}:${var.metabase_pg_password}@postgres:5432/${var.metabase_pg_db}" : null
  sensitive   = true
}

output "metabase_db_creds" {
  description = "Учетные данные для подключения к базе данных Metabase."
  value = var.enable_postgres && var.enable_metabase ? {
    user = var.metabase_pg_user
    db   = var.metabase_pg_db
    pass = var.metabase_pg_password
    host = "postgres"
    port = 5432
  } : null
  sensitive = true
}

# ---- Section: Superset outputs ----
output "superset_db_connection_string" {
  description = "Строка подключения к базе данных Superset."
  value       = var.enable_postgres && var.enable_superset ? "postgresql://${var.superset_pg_user}:${var.superset_pg_password}@postgres:5432/${var.superset_pg_db}" : null
  sensitive   = true
}

output "superset_db_creds" {
  description = "Учетные данные для подключения к базе данных Superset."
  value = var.enable_postgres && var.enable_superset ? {
    user = var.superset_pg_user
    db   = var.superset_pg_db
    pass = var.superset_pg_password
    host = "postgres"
    port = 5432
  } : null
  sensitive = true
}

# ---- Section: Airflow outputs ----
output "airflow_db_connection_string" {
  description = "Строка подключения к базе данных Airflow."
  value       = var.enable_postgres && var.enable_airflow ? "postgresql://${var.airflow_pg_user}:${var.airflow_pg_password}@postgres:5432/${var.airflow_pg_db}" : null
  sensitive   = true
}

output "airflow_db_creds" {
  description = "Учетные данные для подключения к базе данных Airflow."
  value = var.enable_postgres && var.enable_airflow ? {
    user = var.airflow_pg_user
    db   = var.airflow_pg_db
    pass = var.airflow_pg_password
    host = "postgres"
    port = 5432
  } : null
  sensitive = true
}
