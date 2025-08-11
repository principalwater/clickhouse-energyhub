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