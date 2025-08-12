# --- Locals ---
locals {
  dbt_project_name = var.dbt_project_name
  dbt_version      = var.dbt_version
  dbt_core_version = var.dbt_core_version
  dbt_port         = var.dbt_port
  dbt_host         = var.dbt_host
  
  # Пути для dbt - используем абсолютные пути
  dbt_base_path    = abspath(var.dbt_base_path)
  dbt_profiles_path = "${abspath(var.dbt_base_path)}/profiles"
  dbt_logs_path    = "${abspath(var.dbt_base_path)}/logs"
  dbt_target_path  = "${abspath(var.dbt_base_path)}/target"
  dbt_models_path  = "${abspath(var.dbt_base_path)}/models"
  dbt_macros_path  = "${abspath(var.dbt_base_path)}/macros"
  dbt_tests_path   = "${abspath(var.dbt_base_path)}/tests"
  dbt_seeds_path   = "${abspath(var.dbt_base_path)}/seeds"
  dbt_snapshots_path = "${abspath(var.dbt_base_path)}/snapshots"
  dbt_analysis_path = "${abspath(var.dbt_base_path)}/analysis"
  
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

# Создание базы данных otus_default в ClickHouse
resource "null_resource" "create_clickhouse_database" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for ClickHouse to be ready..."
      
      # Ждем, пока контейнер clickhouse-01 станет доступен
      for i in {1..30}; do
        if docker ps | grep -q "clickhouse-01"; then
          echo "Container clickhouse-01 is running!"
          break
        fi
        echo "Waiting for container clickhouse-01... attempt $i/30"
        sleep 2
      done
      
      # Ждем, пока ClickHouse станет доступен внутри контейнера
      for i in {1..30}; do
        if docker exec clickhouse-01 clickhouse-client --user ${var.super_user_name} --password ${var.super_user_password} --query "SELECT 1" 2>/dev/null; then
          echo "ClickHouse is ready inside container!"
          break
        fi
        echo "Waiting for ClickHouse inside container... attempt $i/30"
        sleep 2
      done
      
      echo "Creating otus_default database in ClickHouse..."
      docker exec clickhouse-01 clickhouse-client --user ${var.super_user_name} --password ${var.super_user_password} --query "
        CREATE DATABASE IF NOT EXISTS otus_default ON CLUSTER dwh_prod;
        CREATE DATABASE IF NOT EXISTS otus_default;
        SHOW DATABASES;
      "
      echo "Database otus_default created successfully"
    EOT
  }
  
  depends_on = [null_resource.mk_dbt_dirs]
}

# Создание базовых тестовых таблиц в ClickHouse
resource "null_resource" "create_test_tables" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Creating basic test tables in ClickHouse..."
      docker exec clickhouse-01 clickhouse-client --user ${var.super_user_name} --password ${var.super_user_password} --query "
        USE otus_default;
        
        -- Создаем простую тестовую таблицу
        CREATE TABLE IF NOT EXISTS test_table (
          id UInt32,
          name String,
          created_at DateTime
        ) ENGINE = MergeTree()
        ORDER BY id;
        
        -- Вставляем тестовые данные
        INSERT INTO test_table (id, name, created_at) VALUES 
          (1, 'test1', now()),
          (2, 'test2', now()),
          (3, 'test3', now());
        
        -- Проверяем создание
        SELECT 'Test table created successfully' as status;
        SELECT count() as row_count FROM test_table;
      "
      echo "Test tables created successfully"
    EOT
  }
  
  depends_on = [null_resource.create_clickhouse_database]
}

# Создание базовой структуры моделей
resource "null_resource" "create_dbt_structure" {
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${local.dbt_models_path}/{staging,marts,intermediate}
      mkdir -p ${local.dbt_macros_path}
      mkdir -p ${local.dbt_tests_path}
      mkdir -p ${local.dbt_seeds_path}
      mkdir -p ${local.dbt_snapshots_path}
      mkdir -p ${local.dbt_analysis_path}
    EOT
  }
  
  depends_on = [null_resource.create_test_tables]
}

# Создание dbt_project.yml
resource "local_file" "dbt_project_yml" {
  content = templatefile("${path.module}/templates/dbt_project.yml.tpl", {
    project_name = local.dbt_project_name
    clickhouse_database = local.clickhouse_database
  })
  filename = "${local.dbt_base_path}/dbt_project.yml"
  depends_on = [null_resource.create_clickhouse_database]
}

# Создание profiles.yml для подключения к ClickHouse в проекте
resource "local_file" "profiles_yml" {
  content = templatefile("${path.module}/templates/profiles.yml.tpl", {
    clickhouse_host     = local.clickhouse_host
    clickhouse_port     = local.clickhouse_port
    clickhouse_database = local.clickhouse_database
    clickhouse_user     = local.clickhouse_user
    clickhouse_password = local.clickhouse_password
  })
  filename = "${local.dbt_profiles_path}/profiles.yml"
  depends_on = [null_resource.create_clickhouse_database]
}

# Создание Python виртуального окружения для dbt
resource "null_resource" "setup_dbt_environment" {
  provisioner "local-exec" {
    command = <<-EOT
      cd ${local.dbt_base_path}
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
  filename = "${local.dbt_macros_path}/dq_macros.yml"
  depends_on = [null_resource.create_dbt_structure]
}

# Создание базового теста для DQ проверок
resource "local_file" "dq_test_sql" {
  content = templatefile("${path.module}/templates/dq_test.sql.tpl", {})
  filename = "${local.dbt_tests_path}/dq_test.sql"
  depends_on = [null_resource.create_dbt_structure]
}

# Создание README для dbt проекта
resource "local_file" "dbt_readme" {
  content = templatefile("${path.module}/templates/README.md.tpl", {
    project_name = local.dbt_project_name
    clickhouse_database = local.clickhouse_database
    clickhouse_user = local.clickhouse_user
  })
  filename = "${local.dbt_base_path}/README.md"
  depends_on = [null_resource.create_dbt_structure]
}

# Создание скрипта активации dbt окружения
resource "local_file" "activate_dbt_env" {
  content = <<-EOT
#!/bin/bash
# Скрипт для активации dbt окружения
cd ${local.dbt_base_path}

# Устанавливаем переменную окружения для профилей
export DBT_PROFILES_DIR="${local.dbt_profiles_path}"

# Активируем виртуальное окружение
source dbt_env/bin/activate

echo "dbt environment activated"
echo "dbt version: $(dbt --version)"
echo "profiles directory: $DBT_PROFILES_DIR"
echo ""
echo "Available commands:"
echo "  dbt run - запуск моделей"
echo "  dbt test - запуск тестов"
echo "  dbt docs generate - генерация документации"
echo "  dbt docs serve - запуск документации"
echo "  dbt debug - проверка конфигурации"
echo "  dbt compile - компиляция моделей"
echo "  dbt list - список моделей"
EOT
  filename = "${local.dbt_base_path}/activate_dbt.sh"
  depends_on = [null_resource.setup_dbt_environment]
}

# Установка прав на выполнение для скрипта активации
resource "null_resource" "make_activate_script_executable" {
  provisioner "local-exec" {
    command = "chmod +x ${local.dbt_base_path}/activate_dbt.sh"
  }
  
  depends_on = [local_file.activate_dbt_env]
}
