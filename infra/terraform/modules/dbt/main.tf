terraform {
  required_providers {
    docker = {
      source                = "kreuzwerker/docker"
      version               = "3.6.1"
      configuration_aliases = [docker.remote_host]
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.3"
    }
  }
}

# --- Locals ---
locals {
  dbt_project_name = var.dbt_project_name
  dbt_version      = var.dbt_version
  dbt_port         = var.dbt_port
  dbt_host         = var.dbt_host
  
  # Пути для dbt
  dbt_base_path    = var.dbt_base_path
  dbt_profiles_path = "${var.dbt_base_path}/profiles"
  dbt_logs_path    = "${var.dbt_base_path}/logs"
  dbt_target_path  = "${var.dbt_base_path}/target"
  
  # ClickHouse connection settings
  clickhouse_host     = var.clickhouse_host
  clickhouse_port     = var.clickhouse_port
  clickhouse_database = var.clickhouse_database
  clickhouse_user     = var.clickhouse_user
  clickhouse_password = var.clickhouse_password
}

# --- Resources ---

# Создание директорий для dbt
resource "null_resource" "mk_dbt_dirs" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.dbt_base_path} ${local.dbt_profiles_path} ${local.dbt_logs_path} ${local.dbt_target_path}"
  }
}

# Docker image для dbt
resource "docker_image" "dbt_clickhouse" {
  name = "ghcr.io/dbt-labs/dbt-clickhouse:${local.dbt_version}"
}

# Создание dbt_project.yml
resource "local_file" "dbt_project_yml" {
  content = templatefile("${path.module}/templates/dbt_project.yml.tpl", {
    project_name = local.dbt_project_name
    clickhouse_database = local.clickhouse_database
  })
  filename = "${local.dbt_base_path}/dbt_project.yml"
  depends_on = [null_resource.mk_dbt_dirs]
}

# Создание profiles.yml для подключения к ClickHouse
resource "local_file" "profiles_yml" {
  content = templatefile("${path.module}/templates/profiles.yml.tpl", {
    clickhouse_host     = local.clickhouse_host
    clickhouse_port     = local.clickhouse_port
    clickhouse_database = local.clickhouse_database
    clickhouse_user     = local.clickhouse_user
    clickhouse_password = local.clickhouse_password
  })
  filename = "${local.dbt_profiles_path}/profiles.yml"
  depends_on = [null_resource.mk_dbt_dirs]
}

# Создание Docker Compose для dbt
resource "docker_container" "dbt_clickhouse" {
  name  = "dbt-clickhouse"
  image = docker_image.dbt_clickhouse.image_id
  
  networks_advanced {
    name = var.clickhouse_network_name
  }
  
  volumes {
    container_path = "/dbt"
    host_path     = local.dbt_base_path
    read_only     = false
  }
  
  volumes {
    container_path = "/root/.dbt"
    host_path     = local.dbt_profiles_path
    read_only     = false
  }
  
  working_dir = "/dbt"
  command = [
    "tail", "-f", "/dev/null"  # Keep container running
  ]
  
  depends_on = [
    local_file.dbt_project_yml,
    local_file.profiles_yml
  ]
  
  restart = "unless-stopped"
}

# Создание базовой структуры моделей
resource "null_resource" "create_dbt_structure" {
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${local.dbt_base_path}/models/{staging,marts,intermediate}
      mkdir -p ${local.dbt_base_path}/macros
      mkdir -p ${local.dbt_base_path}/tests
      mkdir -p ${local.dbt_base_path}/seeds
      mkdir -p ${local.dbt_base_path}/snapshots
      mkdir -p ${local.dbt_base_path}/analysis
    EOT
  }
  
  depends_on = [null_resource.mk_dbt_dirs]
}

# Создание базового макроса для DQ проверок
resource "local_file" "dq_macros_yml" {
  content = templatefile("${path.module}/templates/dq_macros.yml.tpl", {})
  filename = "${local.dbt_base_path}/macros/dq_macros.yml"
  depends_on = [null_resource.create_dbt_structure]
}

# Создание базового теста для DQ проверок
resource "local_file" "dq_test_sql" {
  content = templatefile("${path.module}/templates/dq_test.sql.tpl", {})
  filename = "${local.dbt_base_path}/tests/dq_test.sql"
  depends_on = [null_resource.create_dbt_structure]
}

# Создание README для dbt проекта
resource "local_file" "dbt_readme" {
  content = templatefile("${path.module}/templates/README.md.tpl", {
    project_name = local.dbt_project_name
    clickhouse_database = local.clickhouse_database
  })
  filename = "${local.dbt_base_path}/README.md"
  depends_on = [null_resource.create_dbt_structure]
}
