# --- Locals ---
locals {
  dbt_project_name = var.dbt_project_name
  dbt_version      = var.dbt_version
  dbt_core_version = var.dbt_core_version
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
    command = "mkdir -p ${abspath(local.dbt_base_path)} ${abspath(local.dbt_profiles_path)} ${abspath(local.dbt_logs_path)} ${abspath(local.dbt_target_path)}"
  }
}

# Создание базовой структуры моделей
resource "null_resource" "create_dbt_structure" {
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${abspath(local.dbt_base_path)}/models/{staging,marts,intermediate}
      mkdir -p ${abspath(local.dbt_base_path)}/macros
      mkdir -p ${abspath(local.dbt_base_path)}/tests
      mkdir -p ${abspath(local.dbt_base_path)}/seeds
      mkdir -p ${abspath(local.dbt_base_path)}/snapshots
      mkdir -p ${abspath(local.dbt_base_path)}/analysis
    EOT
  }
  
  depends_on = [null_resource.mk_dbt_dirs]
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

# Создание Python виртуального окружения для dbt
resource "null_resource" "setup_dbt_environment" {
  provisioner "local-exec" {
    command = <<-EOT
      cd ${abspath(local.dbt_base_path)}
      python3 -m venv dbt_env
      source dbt_env/bin/activate
      pip install --upgrade pip
      pip install dbt-core==${var.dbt_core_version} dbt-clickhouse==${local.dbt_version}
      pip install clickhouse-connect
      echo "dbt environment setup completed"
    EOT
  }
  
  depends_on = [
    local_file.dbt_project_yml,
    local_file.profiles_yml,
    null_resource.create_dbt_structure
  ]
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

# Создание скрипта активации dbt окружения
resource "local_file" "activate_dbt_env" {
  content = <<-EOT
#!/bin/bash
# Скрипт для активации dbt окружения
cd ${abspath(local.dbt_base_path)}
source dbt_env/bin/activate
echo "dbt environment activated"
echo "dbt version: $(dbt --version)"
echo "Available commands:"
echo "  dbt run - запуск моделей"
echo "  dbt test - запуск тестов"
echo "  dbt docs generate - генерация документации"
echo "  dbt docs serve - запуск документации"
EOT
  filename = "${local.dbt_base_path}/activate_dbt.sh"
  depends_on = [null_resource.setup_dbt_environment]
}

# Установка прав на выполнение для скрипта активации
resource "null_resource" "make_activate_script_executable" {
  provisioner "local-exec" {
    command = "chmod +x ${abspath(local.dbt_base_path)}/activate_dbt.sh"
  }
  
  depends_on = [local_file.activate_dbt_env]
}
