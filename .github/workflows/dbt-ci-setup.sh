#!/bin/bash

# Скрипт для настройки dbt в CI/CD
set -e

echo "Creating dbt project structure..."

# Создаем необходимые директории
mkdir -p profiles logs target

# Создаем dbt_project.yml
cat > dbt_project.yml << 'EOF'
name: 'clickhouse_energyhub'
version: '1.0.0'
config-version: 2
require-dbt-version: ">=1.10.0"

# Настройки профиля
profile: 'clickhouse_energyhub'

# Пути к моделям
model-paths: ["models"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

# Пути для артефактов
target-path: "target"
clean-targets:
  - "target"
  - "dbt_packages"

# Настройки для ClickHouse
models:
  clickhouse_energyhub:
    raw:
      +materialized: table
      +schema: raw
    ods:
      +materialized: table
      +schema: ods
    dds:
      +materialized: table
      +schema: dds
    cdm:
      +materialized: table
      +schema: cdm

# Настройки для тестов
tests:
  +store_failures: true
  +severity: warn

# Настройки для seeds
seeds:
  +schema: raw_data

# Настройки для snapshots
snapshots:
  +target_schema: snapshots

# Макросы для DQ проверок
vars:
  # Переменные для DQ проверок
  dq_enabled: true
  dq_schema: "dq_checks"
  dq_failure_threshold: 0.1  # 10% допустимых ошибок
  
  # Настройки для ClickHouse
  clickhouse_database: "default"
  clickhouse_cluster: "dwh_test"
  
  # Настройки для мониторинга
  enable_dq_monitoring: true
  dq_alert_email: "admin@energyhub.local"
EOF

          # Создаем profiles.yml для CI (offline mode)
          cat > profiles/profiles.yml << 'EOF'
clickhouse_energyhub:
  target: test
  outputs:
    test:
      type: clickhouse
      host: localhost
      port: 9000
      database: default
      user: principalwater
      password: "dummy_password_for_ci"
      schema: default
      threads: 2
      keepalives_idle: 0
      connect_timeout: 1
      send_receive_timeout: 1
      sync_request_timeout: 1
      settings:
        use_numpy: true
        use_pandas_numpy: true
EOF
          
          echo "profiles.yml created successfully"

echo "dbt project structure created successfully"
