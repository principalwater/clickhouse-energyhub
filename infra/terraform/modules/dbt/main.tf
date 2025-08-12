# --- Locals ---
locals {
  dbt_project_name = var.dbt_project_name
  dbt_version      = var.dbt_version
  dbt_core_version = var.dbt_core_version
  dbt_port         = var.dbt_port
  dbt_host         = var.dbt_host

  # Пути для dbt - используем абсолютные пути
  dbt_base_path      = abspath(var.dbt_base_path)
  dbt_profiles_path  = "${abspath(var.dbt_base_path)}/profiles"
  dbt_logs_path      = "${abspath(var.dbt_base_path)}/logs"
  dbt_target_path    = "${abspath(var.dbt_base_path)}/target"
  dbt_models_path    = "${abspath(var.dbt_base_path)}/models"
  dbt_macros_path    = "${abspath(var.dbt_base_path)}/macros"
  dbt_tests_path     = "${abspath(var.dbt_base_path)}/tests"
  dbt_seeds_path     = "${abspath(var.dbt_base_path)}/seeds"
  dbt_snapshots_path = "${abspath(var.dbt_base_path)}/snapshots"
  dbt_analysis_path  = "${abspath(var.dbt_base_path)}/analysis"

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
      
      echo "Creating DWH layer databases in ClickHouse..."
      docker exec clickhouse-01 clickhouse-client --user ${var.super_user_name} --password ${var.super_user_password} --query "
        -- Основная база данных для dbt
        CREATE DATABASE IF NOT EXISTS otus_default ON CLUSTER dwh_prod;
        CREATE DATABASE IF NOT EXISTS otus_default;
        
        -- Слои DWH архитектуры
        CREATE DATABASE IF NOT EXISTS raw ON CLUSTER dwh_prod;
        CREATE DATABASE IF NOT EXISTS raw;
        
        CREATE DATABASE IF NOT EXISTS ods ON CLUSTER dwh_prod;
        CREATE DATABASE IF NOT EXISTS ods;
        
        CREATE DATABASE IF NOT EXISTS dds ON CLUSTER dwh_prod;
        CREATE DATABASE IF NOT EXISTS dds;
        
        CREATE DATABASE IF NOT EXISTS cdm ON CLUSTER dwh_prod;
        CREATE DATABASE IF NOT EXISTS cdm;
        
        -- Показываем все созданные базы данных
        SHOW DATABASES;
      "
      echo "DWH layer databases created successfully"
    EOT
  }

  depends_on = [null_resource.mk_dbt_dirs]
}

# Создание тестовых данных в raw слое
resource "null_resource" "create_raw_test_data" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Creating test data in raw layer..."
      docker exec clickhouse-01 clickhouse-client --user ${var.super_user_name} --password ${var.super_user_password} --query "
        USE raw;
        
        -- Создаем таблицу с сырыми данными об энергопотреблении
        CREATE TABLE IF NOT EXISTS energy_consumption_raw (
          device_id UInt32,
          location_id UInt32,
          timestamp DateTime,
          energy_kwh Float64,
          voltage Float64,
          current_amp Float64,
          power_factor Float64,
          temperature Float64,
          humidity Float64,
          raw_data String
        ) ENGINE = MergeTree()
        ORDER BY (device_id, timestamp)
        PARTITION BY toYYYYMM(timestamp);
        
        -- Создаем таблицу с сырыми данными об устройствах
        CREATE TABLE IF NOT EXISTS devices_raw (
          device_id UInt32,
          device_name String,
          device_type String,
          location_id UInt32,
          manufacturer String,
          model String,
          installation_date Date,
          last_maintenance_date Date,
          status String,
          raw_data String
        ) ENGINE = MergeTree()
        ORDER BY device_id;
        
        -- Создаем таблицу с сырыми данными о локациях
        CREATE TABLE IF NOT EXISTS locations_raw (
          location_id UInt32,
          location_name String,
          region String,
          city String,
          address String,
          latitude Float64,
          longitude Float64,
          timezone String,
          country String,
          raw_data String
        ) ENGINE = MergeTree()
        ORDER BY location_id;
        
        -- Генерируем тестовые данные для энергопотребления
        INSERT INTO energy_consumption_raw 
        SELECT 
          number % 10 + 1 as device_id,
          (number % 5) + 1 as location_id,
          now() - INTERVAL (number * 15) MINUTE as timestamp,
          100 + (rand() % 50) as energy_kwh,
          220 + (rand() % 20) as voltage,
          10 + (rand() % 5) as current_amp,
          0.8 + (rand() % 20) / 100 as power_factor,
          20 + (rand() % 15) as temperature,
          40 + (rand() % 30) as humidity,
          '{\"source\": \"iot_sensor\", \"version\": \"1.0\"}' as raw_data
        FROM numbers(1000);
        
        -- Генерируем тестовые данные для устройств
        INSERT INTO devices_raw VALUES
          (1, 'Smart Meter A1', 'electricity_meter', 1, 'Siemens', 'SM-1000', '2023-01-15', '2024-01-15', 'active', '{\"warranty\": \"2_years\"}'),
          (2, 'Smart Meter A2', 'electricity_meter', 1, 'Siemens', 'SM-1000', '2023-02-20', '2024-02-20', 'active', '{\"warranty\": \"2_years\"}'),
          (3, 'Solar Panel B1', 'solar_panel', 2, 'SolarTech', 'SP-500', '2023-03-10', '2024-03-10', 'active', '{\"efficiency\": \"0.85\"}'),
          (4, 'Wind Turbine C1', 'wind_turbine', 3, 'WindPower', 'WT-1000', '2023-04-05', '2024-04-05', 'active', '{\"capacity\": \"1MW\"}'),
          (5, 'Battery Storage D1', 'battery', 4, 'PowerStore', 'BS-200', '2023-05-12', '2024-05-12', 'active', '{\"capacity\": \"200kWh\"}');
        
        -- Генерируем тестовые данные для локаций
        INSERT INTO locations_raw VALUES
          (1, 'Office Building Alpha', 'North', 'Moscow', 'Tverskaya St, 1', 55.7558, 37.6176, 'Europe/Moscow', 'Russia', '{\"building_type\": \"office\"}'),
          (2, 'Solar Farm Beta', 'South', 'Krasnodar', 'Solar St, 15', 45.0448, 38.9760, 'Europe/Moscow', 'Russia', '{\"facility_type\": \"solar_farm\"}'),
          (3, 'Wind Farm Gamma', 'West', 'Kaliningrad', 'Wind Ave, 25', 54.7074, 20.5073, 'Europe/Kaliningrad', 'Russia', '{\"facility_type\": \"wind_farm\"}'),
          (4, 'Industrial Complex Delta', 'East', 'Vladivostok', 'Industrial Blvd, 100', 43.1198, 131.8869, 'Asia/Vladivostok', 'Russia', '{\"facility_type\": \"industrial\"}'),
          (5, 'Residential Area Epsilon', 'Central', 'Kazan', 'Residential St, 50', 55.7887, 49.1221, 'Europe/Moscow', 'Russia', '{\"facility_type\": \"residential\"}');
        
        -- Проверяем создание данных
        SELECT 'Raw test data created successfully' as status;
        SELECT 'Energy consumption records:' as info, count() as count FROM energy_consumption_raw
        UNION ALL
        SELECT 'Device records:' as info, count() as count FROM devices_raw
        UNION ALL
        SELECT 'Location records:' as info, count() as count FROM locations_raw;
      "
      echo "Raw test data created successfully"
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

  depends_on = [null_resource.create_raw_test_data]
}

# Создание dbt_project.yml
resource "local_file" "dbt_project_yml" {
  content = templatefile("${path.module}/templates/dbt_project.yml.tpl", {
    project_name        = local.dbt_project_name
    clickhouse_database = local.clickhouse_database
  })
  filename   = "${local.dbt_base_path}/dbt_project.yml"
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
  filename   = "${local.dbt_profiles_path}/profiles.yml"
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
  content    = templatefile("${path.module}/templates/dq_macros.yml.tpl", {})
  filename   = "${local.dbt_macros_path}/dq_macros.yml"
  depends_on = [null_resource.create_dbt_structure]
}

# Создание базового теста для DQ проверок
resource "local_file" "dq_test_sql" {
  content    = templatefile("${path.module}/templates/dq_test.sql.tpl", {})
  filename   = "${local.dbt_tests_path}/dq_test.sql"
  depends_on = [null_resource.create_dbt_structure]
}

# Создание README для dbt проекта
resource "local_file" "dbt_readme" {
  content = templatefile("${path.module}/templates/README.md.tpl", {
    project_name        = local.dbt_project_name
    clickhouse_database = local.clickhouse_database
    clickhouse_user     = local.clickhouse_user
  })
  filename   = "${local.dbt_base_path}/README.md"
  depends_on = [null_resource.create_dbt_structure]
}

# Создание скрипта активации dbt окружения
resource "local_file" "activate_dbt_env" {
  content    = <<-EOT
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
  filename   = "${local.dbt_base_path}/activate_dbt.sh"
  depends_on = [null_resource.setup_dbt_environment]
}

# Установка прав на выполнение для скрипта активации
resource "null_resource" "make_activate_script_executable" {
  provisioner "local-exec" {
    command = "chmod +x ${local.dbt_base_path}/activate_dbt.sh"
  }

  depends_on = [local_file.activate_dbt_env]
}
