# Интеграция dbt с ClickHouse

## Обзор

Этот документ описывает интеграцию dbt (data build tool) с ClickHouse в рамках проекта ClickHouse EnergyHub. Интеграция основана на официальном плагине [dbt-clickhouse](https://github.com/ClickHouse/dbt-clickhouse).

## Установка и настройка

### Требования

- Python 3.9+
- dbt-core >= 1.10.0
- dbt-clickhouse >= 1.9.2
- ClickHouse >= 22.1

### Компоненты

```bash
# Основные пакеты
dbt-core==1.10.7          # Ядро dbt
dbt-clickhouse==1.9.2     # Адаптер для ClickHouse
clickhouse-connect         # Python драйвер для ClickHouse
```

## Конфигурация

### dbt_project.yml

```yaml
name: 'clickhouse_energyhub'
version: '1.0.0'
config-version: 2
require-dbt-version: ">=1.10.0"

# Настройки профиля
profile: 'clickhouse_energyhub'

# Пути к моделям
model-paths: ["models"]
analysis-paths: ["analysis"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

# Настройки для ClickHouse
models:
  clickhouse_energyhub:
    staging:
      +materialized: view
      +schema: staging
    marts:
      +materialized: table
      +schema: marts
    intermediate:
      +materialized: view
      +schema: intermediate
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
      database: otus_default  # Не используйте 'default'!
      user: <ваш_super_user_name>  # Используем super_user для полных прав
      password: ${DBT_CLICKHOUSE_PASSWORD}
      schema: default
      threads: 4
      
      # Настройки для ClickHouse
      clickhouse_settings:
        use_default_database: 1
        allow_experimental_object_type: 1
        allow_experimental_map_type: 1
        allow_experimental_low_cardinality_type: 1
```

## Материализации

### 1. View (по умолчанию)

```sql
-- models/staging/stg_energy_consumption.sql
SELECT 
    device_id,
    timestamp,
    energy_kwh,
    location_id
FROM {{ source('raw', 'energy_consumption') }}
WHERE timestamp >= '{{ var("start_date", "2024-01-01") }}'
```

### 2. Table

```sql
-- models/marts/dim_locations.sql
{{ config(materialized='table') }}

SELECT 
    location_id,
    location_name,
    city,
    country,
    region,
    latitude,
    longitude
FROM {{ ref('staging', 'stg_locations') }}
```

### 3. Incremental

```sql
-- models/marts/fact_energy_daily.sql
{{ config(
    materialized='incremental',
    unique_key=['date_key', 'device_id', 'location_id'],
    incremental_strategy='append'  # или 'delete+insert', 'insert_overwrite'
) }}

SELECT 
    toDate(timestamp) as date_key,
    device_id,
    location_id,
    sum(energy_kwh) as daily_energy_kwh,
    count(*) as readings_count,
    avg(energy_kwh) as avg_energy_kwh
FROM {{ ref('staging', 'stg_energy_consumption') }}
WHERE timestamp >= '{{ var("start_date", "2024-01-01") }}'

{% if is_incremental() %}
  AND timestamp > (SELECT max(timestamp) FROM {{ this }})
{% endif %}

GROUP BY date_key, device_id, location_id
```

### 4. Ephemeral

```sql
-- models/intermediate/int_energy_hourly.sql
{{ config(materialized='ephemeral') }}

SELECT 
    toStartOfHour(timestamp) as hour_key,
    device_id,
    location_id,
    sum(energy_kwh) as hourly_energy_kwh
FROM {{ ref('staging', 'stg_energy_consumption') }}
GROUP BY hour_key, device_id, location_id
```

## Стратегии инкрементальной материализации

### Append Strategy (inserts-only)

```sql
{{ config(
    materialized='incremental',
    incremental_strategy='append',
    unique_key=['date_key', 'device_id']
) }}
```

**Применение**: Для неизменяемых данных, где дубликаты допустимы.

### Delete and Insert Mode

```sql
{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['date_key', 'device_id']
) }}
```

**Применение**: Для данных, которые могут обновляться.

### Insert Overwrite Mode

```sql
{{ config(
    materialized='incremental',
    incremental_strategy='insert_overwrite',
    unique_key=['date_key', 'device_id']
) }}
```

**Применение**: Для замены партиций, более безопасно.

## Snapshots

```sql
-- snapshots/energy_consumption_snapshot.sql
{% snapshot energy_consumption_snapshot %}

{{
    config(
      target_schema='snapshots',
      strategy='timestamp',
      unique_key='id',
      updated_at='updated_at',
    )
}}

select * from {{ ref('staging', 'stg_energy_consumption') }}

{% endsnapshot %}
```

## Seeds

```sql
-- seeds/device_types.csv
device_type_id,device_type_name,description
1,smart_meter,Smart electricity meter
2,solar_panel,Solar panel inverter
3,battery_storage,Battery storage system
4,wind_turbine,Wind turbine generator
```

## Тестирование

### Generic Tests

```sql
-- models/marts/fact_energy_daily.sql
{{ config(
    materialized='table',
    tags=['daily_energy', 'fact_table']
) }}

SELECT 
    toDate(timestamp) as date_key,
    device_id,
    location_id,
    sum(energy_kwh) as daily_energy_kwh
FROM {{ ref('staging', 'stg_energy_consumption') }}
GROUP BY date_key, device_id, location_id

-- Тесты
{{ config(
    tests=[
        "not_null",
        "unique",
        "accepted_range"
    ]
) }}
```

### Custom Tests

```sql
-- tests/assert_positive_energy.sql
SELECT *
FROM {{ ref('fact_energy_daily') }}
WHERE daily_energy_kwh < 0
```

## Макросы

### ClickHouse-специфичные макросы

```sql
-- macros/clickhouse_utils.sql

-- Макрос для партиционирования по месяцам
{% macro clickhouse_partition_by_month(column_name) %}
    toYYYYMM({{ column_name }})
{% endmacro %}

-- Макрос для оптимизации MergeTree
{% macro clickhouse_merge_tree_settings() %}
    ENGINE = MergeTree()
    PARTITION BY {{ clickhouse_partition_by_month('timestamp') }}
    ORDER BY (device_id, timestamp)
    SETTINGS index_granularity = 8192
{% endmacro %}
```

## Ограничения и рекомендации

### 1. **Не используйте базу `default`**
```yaml
# ❌ Плохо
database: default

# ✅ Хорошо  
database: otus_default
```

### 2. **Оптимизация для больших данных**
- Используйте `GROUP BY` для агрегации
- Предпочитайте модели, которые суммируют данные
- Избегайте простых трансформаций с сохранением количества строк

### 3. **Партиционирование**
```sql
-- Рекомендуется для больших таблиц
PARTITION BY toYYYYMM(timestamp)
ORDER BY (device_id, timestamp)
```

### 4. **Distributed таблицы**
Для кластерных таблиц создавайте вручную:
```sql
-- Создайте ReplicatedMergeTree таблицы на каждом узле
-- Затем создайте Distributed таблицу поверх них
```

## Мониторинг и отладка

### Логи dbt

```bash
# Запуск с подробными логами
dbt run --verbose

# Просмотр SQL без выполнения
dbt compile

# Проверка зависимостей
dbt list
```

### ClickHouse логи

```sql
-- Просмотр запросов dbt
SELECT 
    query,
    query_duration_ms,
    memory_usage,
    timestamp
FROM system.query_log 
WHERE query LIKE '%dbt%'
ORDER BY timestamp DESC
LIMIT 100
```

## Примеры использования

### Полный пайплайн

1. **Staging**: Очистка и валидация сырых данных
2. **Intermediate**: Агрегация по часам/дням
3. **Marts**: Бизнес-логика и KPI
4. **Snapshots**: Отслеживание изменений

### Команды

```bash
# Активация окружения
source dbt_env/bin/activate

# Запуск всех моделей
dbt run

# Запуск конкретной модели
dbt run --select marts.fact_energy_daily

# Запуск тестов
dbt test

# Генерация документации
dbt docs generate
dbt docs serve

# Создание снапшотов
dbt snapshot

# Загрузка seeds
dbt seed
```

## Ресурсы

- [Официальная документация ClickHouse по dbt](https://clickhouse.com/docs/integrations/dbt)
- [dbt-clickhouse GitHub](https://github.com/ClickHouse/dbt-clickhouse)
- [dbt документация](https://docs.getdbt.com/)
- [ClickHouse документация](https://clickhouse.com/docs/)

## Поддержка

При возникновении проблем:
1. Проверьте логи dbt и ClickHouse
2. Убедитесь в совместимости версий
3. Проверьте настройки подключения
4. Обратитесь к команде Data Engineering
