# 🔗 Интеграция dbt с ClickHouse

## Обзор

ClickHouse EnergyHub использует **dbt (data build tool)** для трансформации данных в ClickHouse. Эта интеграция обеспечивает декларативный подход к созданию моделей данных, автоматическое тестирование и документацию.

## 🏗️ Архитектура интеграции

### Компоненты системы

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   ClickHouse    │    │      dbt        │    │     Airflow     │
│                 │    │                 │    │                 │
│ • Raw Tables    │◄───┤ • Models        │◄───┤ • DAGs          │
│ • ODS Tables    │    │ • Tests         │    │ • Scheduling    │
│ • DDS Tables    │    │ • Sources       │    │ • Monitoring    │
│ • CDM Tables    │    │ • Macros        │    │ • Logs          │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Поток данных

```
1. ClickHouse Tables → 2. dbt Sources → 3. dbt Models → 4. ClickHouse Tables
     ↓                       ↓              ↓              ↓
  Data Storage         Metadata        Transformation   Processed Data
```

## 📁 Структура проекта dbt

```
dbt/
├── dbt_project.yml          # Конфигурация проекта
├── profiles.yml             # Профили подключения
├── packages.yml             # Зависимости
├── models/                  # Модели данных
│   ├── sources.yml          # Определение источников
│   ├── raw/                 # Модели для raw слоя
│   ├── ods/                 # Модели для ODS слоя
│   ├── dds/                 # Модели для DDS слоя
│   └── cdm/                 # Модели для CDM слоя
├── tests/                   # Кастомные тесты
├── macros/                  # Макросы
├── seeds/                   # Статические данные
└── target/                  # Скомпилированные модели
```

## ⚙️ Конфигурация

### dbt_project.yml

```yaml
name: 'clickhouse_energyhub'
version: '1.0.0'
config-version: 2

profile: 'clickhouse_energyhub'

model-paths: ["models"]
analysis-paths: ["analyses"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

target-path: "target"
clean-targets:
  - "target"
  - "dbt_packages"

models:
  clickhouse_energyhub:
    materialized: table
    raw:
      materialized: table
      tags: ["raw"]
    ods:
      materialized: table
      tags: ["ods"]
    dds:
      materialized: table
      tags: ["dds"]
    cdm:
      materialized: table
      tags: ["cdm"]

vars:
  clickhouse_database: "default"
  clickhouse_cluster: "clickhouse_cluster"
```

### profiles.yml

```yaml
clickhouse_energyhub:
  target: dev
  outputs:
    dev:
      type: clickhouse
      host: clickhouse-01
      port: 9000
      user: principalwater
      password: UnixSpace@11.
      database: default
      schema: default
      threads: 4
      keepalives_idle: 0
      connect_timeout: 10
      send_receive_timeout: 300
      sync_request_timeout: 5
      compression: True
      secure: False
      verify: False
      client_name: dbt
      settings:
        optimize_aggregation_in_order: 1
        max_threads: 8
        max_memory_usage: 8589934592
```

### packages.yml

```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: 1.1.1
  - package: dbt-labs/audit_helper
    version: 0.9.0
  - package: metaplane/dbt_expectations
    version: 0.10.4
  - package: godatadriven/dbt_date
    version: 0.10.1
```

## 🏗️ Модели данных

### Типы моделей

#### 1. **Raw Models** (Сырые данные)
```sql
-- models/raw/raw_river_flow.sql
{{
  config(
    materialized='table',
    tags=['raw', 'river_flow']
  )
}}

SELECT 
  ges_name,
  timestamp,
  river_name,
  water_level_m,
  flow_rate_m3_s,
  power_output_mw,
  now() as loaded_at
FROM {{ source('raw', 'river_flow') }}
WHERE timestamp >= '{{ var("start_date", "2020-01-01") }}'
```

#### 2. **ODS Models** (Операционные данные)
```sql
-- models/ods/ods_river_flow.sql
{{
  config(
    materialized='table',
    tags=['ods', 'river_flow']
  )
}}

SELECT 
  ges_name,
  timestamp,
  river_name,
  CAST(water_level_m AS Float64) as water_level_m,
  CAST(flow_rate_m3_s AS Float64) as flow_rate_m3_s,
  CAST(power_output_mw AS Float64) as power_output_mw,
  now() as processed_at
FROM {{ ref('raw_river_flow') }}
WHERE ges_name IS NOT NULL
  AND timestamp IS NOT NULL
  AND river_name IS NOT NULL
```

#### 3. **DDS Models** (Детализированные данные)
```sql
-- models/dds/dds_river_flow_clean.sql
{{
  config(
    materialized='table',
    tags=['dds', 'river_flow', 'clean']
  )
}}

WITH deduplicated_river_flow AS (
  SELECT 
    ges_name,
    timestamp,
    river_name,
    water_level_m,
    flow_rate_m3_s,
    power_output_mw,
    ROW_NUMBER() OVER (
      PARTITION BY ges_name, timestamp, river_name 
      ORDER BY timestamp DESC
    ) as rn
  FROM {{ source('raw', 'river_flow') }}
  WHERE ges_name IS NOT NULL 
    AND timestamp IS NOT NULL 
    AND river_name IS NOT NULL
)

SELECT 
  ges_name,
  timestamp,
  river_name,
  water_level_m,
  flow_rate_m3_s,
  power_output_mw,
  now() as inserted_at,
  'dbt_clean' as source
FROM deduplicated_river_flow
WHERE rn = 1
```

#### 4. **CDM Models** (Конформированные данные)
```sql
-- models/cdm/cdm_daily_river_flow_summary.sql
{{
  config(
    materialized='table',
    tags=['cdm', 'river_flow', 'summary']
  )
}}

SELECT 
  toDate(timestamp) as date,
  ges_name,
  river_name,
  COUNT(*) as record_count,
  AVG(water_level_m) as avg_water_level,
  AVG(flow_rate_m3_s) as avg_flow_rate,
  AVG(power_output_mw) as avg_power_output,
  MAX(water_level_m) as max_water_level,
  MIN(water_level_m) as min_water_level,
  now() as calculated_at
FROM {{ ref('dds_river_flow_clean') }}
GROUP BY toDate(timestamp), ges_name, river_name
ORDER BY date DESC, ges_name, river_name
```

### View Models

```sql
-- models/dds/dds_river_flow_view.sql
{{
  config(
    materialized='view',
    tags=['dds', 'river_flow', 'view']
  )
}}

SELECT 
  ges_name,
  timestamp,
  river_name,
  water_level_m,
  flow_rate_m3_s,
  power_output_mw,
  inserted_at,
  source
FROM {{ ref('dds_river_flow_clean') }}
WHERE inserted_at >= now() - INTERVAL 30 DAY
```

## 🧪 Тестирование

### Автоматические тесты

#### 1. **Generic Tests** (Встроенные тесты)
```yaml
# models/dds/schema.yml
version: 2

models:
  - name: dds_river_flow_clean
    description: "Очищенные данные river_flow без дублей"
    columns:
      - name: ges_name
        description: "Название ГЭС"
        tests:
          - not_null
          - dbt_utils.not_empty_string
      
      - name: timestamp
        description: "Временная метка"
        tests:
          - not_null
      
      - name: water_level_m
        description: "Уровень воды в метрах"
        tests:
          - not_null
          - dbt_utils.accepted_range:
              min_value: 0
              max_value: 1000
```

#### 2. **Custom Tests** (Кастомные тесты)
```sql
-- tests/test_no_duplicates.sql
SELECT 
  ges_name,
  timestamp,
  river_name,
  COUNT(*) as record_count
FROM {{ ref('dds_river_flow_clean') }}
GROUP BY ges_name, timestamp, river_name
HAVING COUNT(*) > 1
```

#### 3. **Data Tests** (Тесты данных)
```sql
-- tests/test_data_quality.sql
SELECT 
  'water_level_out_of_range' as test_name,
  COUNT(*) as failed_records
FROM {{ ref('dds_river_flow_clean') }}
WHERE water_level_m < 0 OR water_level_m > 1000

UNION ALL

SELECT 
  'flow_rate_out_of_range' as test_name,
  COUNT(*) as failed_records
FROM {{ ref('dds_river_flow_clean') }}
WHERE flow_rate_m3_s < 0 OR flow_rate_m3_s > 10000
```

### Запуск тестов

```bash
# Все тесты
dbt test

# Тесты для конкретной модели
dbt test --select dds_river_flow_clean

# Тесты для конкретного тега
dbt test --select tag:clean

# Кастомные тесты
dbt test --select test_no_duplicates
```

## 🔄 Источники данных

### Автоматическое обновление sources.yml

Система автоматически обновляет `sources.yml` на основе таблиц в ClickHouse:

```yaml
# models/sources.yml (автоматически генерируется)
version: 2

sources:
  - name: raw
    description: "Tables from raw database"
    database: raw
    schema: raw
    tables:
      - name: river_flow
        description: "Raw river flow data"
        columns:
          - name: ges_name
            description: "Name of the hydroelectric power station"
            tests:
              - not_null
          - name: timestamp
            description: "Measurement timestamp"
            tests:
              - not_null
          # ... другие колонки
```

### Ручное определение источников

```yaml
# models/sources.yml (ручное определение)
version: 2

sources:
  - name: external_api
    description: "External API data sources"
    tables:
      - name: weather_data
        description: "Weather information from external API"
        columns:
          - name: timestamp
            description: "Weather measurement time"
            tests:
              - not_null
          - name: temperature
            description: "Temperature in Celsius"
            tests:
              - not_null
              - dbt_utils.accepted_range:
                  min_value: -50
                  max_value: 60
```

## 🎯 Макросы

### Полезные макросы для ClickHouse

#### 1. **Партиционирование по времени**
```sql
-- macros/partition_by_time.sql
{% macro partition_by_time(column_name) %}
  PARTITION BY toYYYYMM({{ column_name }})
{% endmacro %}
```

#### 2. **Оптимизация для ClickHouse**
```sql
-- macros/clickhouse_optimize.sql
{% macro clickhouse_optimize() %}
  OPTIMIZE TABLE {{ this }} FINAL
{% endmacro %}
```

#### 3. **Генерация дат**
```sql
-- macros/generate_date_spine.sql
{% macro generate_date_spine(datepart, start_date, end_date) %}
  SELECT 
    toDate(date) as date
  FROM (
    SELECT 
      toDate('{{ start_date }}') + INTERVAL number DAY as date
    FROM numbers(
      dateDiff('day', '{{ start_date }}', '{{ end_date }}') + 1
    )
  )
{% endmacro %}
```

### Использование макросов

```sql
-- models/cdm/cdm_daily_summary.sql
{{
  config(
    materialized='table',
    tags=['cdm', 'summary']
  )
}}

SELECT 
  d.date,
  COUNT(r.record_id) as record_count
FROM {{ generate_date_spine('day', '2020-01-01', '2024-12-31') }} d
LEFT JOIN {{ ref('raw_records') }} r ON toDate(r.timestamp) = d.date
GROUP BY d.date
ORDER BY d.date
```

## 📊 Документация

### Генерация документации

```bash
# Генерация документации
dbt docs generate

# Запуск веб-сервера документации
dbt docs serve --port 8080
```

### Структура документации

```
📚 dbt Documentation
├── 🏠 Home
├── 📁 Models
│   ├── Raw Layer
│   ├── ODS Layer
│   ├── DDS Layer
│   └── CDM Layer
├── 🔗 Sources
├── 🧪 Tests
├── 📊 Lineage Graph
└── 📈 DAG View
```

## 🚀 Интеграция с Airflow

### DAG для dbt

```python
# airflow/dags/dbt_pipeline.py
from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime, timedelta

default_args = {
    'owner': 'energy-hub',
    'depends_on_past': False,
    'start_date': datetime(2025, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'dbt_pipeline',
    default_args=default_args,
    description='dbt data transformation pipeline',
    schedule='0 */2 * * *',  # Каждые 2 часа
    catchup=False,
)

# Задачи dbt
run_models = BashOperator(
    task_id='run_dbt_models',
    bash_command='cd /opt/airflow/dbt && dbt run',
    dag=dag,
)

run_tests = BashOperator(
    task_id='run_dbt_tests',
    bash_command='cd /opt/airflow/dbt && dbt test',
    dag=dag,
)

generate_docs = BashOperator(
    task_id='generate_dbt_docs',
    bash_command='cd /opt/airflow/dbt && dbt docs generate',
    dag=dag,
)

# Зависимости
run_models >> run_tests >> generate_docs
```

### Мониторинг в Airflow

- **Логи выполнения** каждой dbt команды
- **Время выполнения** моделей
- **Статус тестов** (PASS/FAIL)
- **Уведомления** об ошибках

## 🔧 Оптимизация производительности

### ClickHouse специфичные настройки

#### 1. **Партиционирование**
```sql
-- Оптимальное партиционирование для временных рядов
PARTITION BY toYYYYMM(timestamp)
ORDER BY (timestamp, entity_id)
```

#### 2. **Индексы**
```sql
-- Создание индексов для часто используемых колонок
ALTER TABLE dds_river_flow_clean 
ADD INDEX idx_ges_name ges_name TYPE bloom_filter GRANULARITY 1;
```

#### 3. **Материализованные представления**
```sql
-- Автоматическое обновление агрегированных данных
CREATE MATERIALIZED VIEW cdm_daily_summary_mv
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(date)
ORDER BY (date, ges_name)
AS SELECT 
    toDate(timestamp) as date,
    ges_name,
    COUNT(*) as record_count,
    AVG(water_level_m) as avg_water_level
FROM dds_river_flow_clean
GROUP BY date, ges_name;
```

### dbt оптимизации

#### 1. **Инкрементальные модели**
```sql
-- models/dds/dds_river_flow_incremental.sql
{{
  config(
    materialized='incremental',
    unique_key='id',
    incremental_strategy='delete+insert'
  )
}}

SELECT 
  id,
  ges_name,
  timestamp,
  -- ... другие колонки
FROM {{ source('raw', 'river_flow') }}

{% if is_incremental() %}
  WHERE timestamp > (SELECT MAX(timestamp) FROM {{ this }})
{% endif %}
```

#### 2. **Параллельное выполнение**
```yaml
# dbt_project.yml
threads: 8  # Количество параллельных потоков
```

## 🚨 Устранение неполадок

### Частые проблемы

#### 1. **Ошибки подключения к ClickHouse**
```bash
# Проверка доступности
docker exec clickhouse-01 clickhouse-client --query "SELECT 1"

# Проверка профиля dbt
dbt debug --config-dir .
```

#### 2. **Ошибки компиляции**
```bash
# Проверка синтаксиса
dbt compile --select model_name

# Проверка зависимостей
dbt deps
```

#### 3. **Проблемы с производительностью**
```sql
-- Анализ запросов в ClickHouse
SELECT 
  query,
  query_duration_ms,
  memory_usage
FROM system.query_log
WHERE type = 'QueryFinish'
ORDER BY query_duration_ms DESC
LIMIT 10;
```

### Диагностика

#### 1. **Логи dbt**
```bash
# Подробные логи
dbt run --verbose

# Логи в файл
dbt run --log-file dbt.log
```

#### 2. **Логи ClickHouse**
```bash
# Логи запросов
docker exec clickhouse-01 tail -f /var/log/clickhouse-server/clickhouse-server.log

# Логи ошибок
docker exec clickhouse-01 tail -f /var/log/clickhouse-server/clickhouse-server.err.log
```

## 📈 Мониторинг и метрики

### Ключевые метрики

- **Время выполнения** моделей
- **Количество записей** в таблицах
- **Качество данных** (результаты тестов)
- **Использование ресурсов** ClickHouse

### Алерты

- **Сбои в пайплайнах** dbt
- **Ошибки тестирования**
- **Долгое выполнение** моделей
- **Проблемы с качеством** данных

## 🔮 Планы развития

### Краткосрочные (3-6 месяцев)
- [ ] Автоматизация тестирования данных
- [ ] Улучшение документации
- [ ] Оптимизация производительности

### Среднесрочные (6-12 месяцев)
- [ ] Machine Learning модели
- [ ] Real-time трансформации
- [ ] Расширенные макросы

### Долгосрочные (1+ год)
- [ ] AI-powered data quality
- [ ] Automated data lineage
- [ ] Multi-database support

## 📚 Дополнительные ресурсы

- [dbt Documentation](https://docs.getdbt.com/)
- [ClickHouse Documentation](https://clickhouse.com/docs/)
- [dbt-utils Package](https://hub.getdbt.com/dbt-labs/dbt_utils/)
- [dbt Best Practices](https://docs.getdbt.com/guides/best-practices)
