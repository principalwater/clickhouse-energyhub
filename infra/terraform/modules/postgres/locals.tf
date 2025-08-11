locals {
  # Fallback logic for Postgres superuser password
  effective_postgres_superuser_password = coalesce(var.postgres_superuser_password, var.pg_password)

  # Fallback logic for BI tool Postgres passwords
  effective_metabase_pg_password = coalesce(var.metabase_pg_password, var.pg_password)
  effective_superset_pg_password = coalesce(var.superset_pg_password, var.pg_password)
  effective_airflow_pg_password  = coalesce(var.airflow_pg_password, var.pg_password)
}
