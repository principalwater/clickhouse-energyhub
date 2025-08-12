name: '${project_name}'
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
  ${project_name}:
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
  clickhouse_database: "${clickhouse_database}"
  clickhouse_cluster: "dwh_test"
  
  # Настройки для мониторинга
  enable_dq_monitoring: true
  dq_alert_email: "admin@energyhub.local"
