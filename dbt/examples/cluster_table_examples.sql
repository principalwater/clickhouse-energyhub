-- Примеры использования кластерных макросов для ClickHouse EnergyHub
-- Демонстрация новой логики именования с суффиксом _local

-- 1. Создание ReplicatedMergeTree таблицы с использованием макроса
-- Результат: создается таблица dim_locations_local
{{ create_replicated_table(
    'dim_locations',
    columns=[
        {'name': 'location_id', 'type': 'UInt32'},
        {'name': 'location_name', 'type': 'String'},
        {'name': 'region', 'type': 'String'},
        {'name': 'city', 'type': 'String'},
        {'name': 'country', 'type': 'String'},
        {'name': 'created_at', 'type': 'DateTime'},
        {'name': 'updated_at', 'type': 'DateTime'}
    ],
    order_by='location_id',
    partition_by='PARTITION BY toYYYYMM(created_at)',
    settings="SETTINGS replication_alter_partitions_sync = 2, compression_codec = 'ZSTD(3)'"
) }}

-- 2. Создание Distributed таблицы, ссылающейся на _local таблицу
-- Результат: создается таблица dim_locations (Distributed)
{{ create_distributed_table(
    'dim_locations',
    'dim_locations',
    'cityHash64(location_id)'
) }}

-- 3. Прямое использование макроса для движка
-- Для ReplicatedMergeTree таблицы
CREATE TABLE IF NOT EXISTS dds.fact_energy_consumption_local ON CLUSTER dwh_prod (
    date_key Date,
    device_id UInt32,
    location_id UInt32,
    total_consumption Float64,
    measurement_count UInt32,
    dbt_updated_at DateTime
) {{ clickhouse_replicated_engine(
    engine_type='MergeTree',
    order_by='(date_key, device_id, location_id)',
    partition_by='PARTITION BY toYYYYMM(date_key)',
    settings="SETTINGS replication_alter_partitions_sync = 2"
) }};

-- 4. Создание Distributed таблицы для fact таблицы
CREATE TABLE IF NOT EXISTS dds.fact_energy_consumption ON CLUSTER dwh_prod AS dds.fact_energy_consumption_local
{{ clickhouse_distributed_engine(
    'fact_energy_consumption',
    'cityHash64(device_id)'
) }};

-- 5. Пример создания промежуточной таблицы с _local суффиксом
{{ create_replicated_table(
    'int_energy_consumption_hourly',
    columns=[
        {'name': 'date_key', 'type': 'Date'},
        {'name': 'hour_key', 'type': 'UInt8'},
        {'name': 'device_id', 'type': 'UInt32'},
        {'name': 'total_consumption', 'type': 'Float64'},
        {'name': 'measurement_count', 'type': 'UInt32'},
        {'name': 'dq_score', 'type': 'Float64'},
        {'name': 'dbt_updated_at', 'type': 'DateTime'}
    ],
    order_by='(date_key, hour_key, device_id)',
    partition_by='PARTITION BY toYYYYMM(date_key)'
) }}

-- 6. Создание Distributed таблицы для промежуточной таблицы
{{ create_distributed_table(
    'int_energy_consumption_hourly',
    'int_energy_consumption_hourly',
    'cityHash64(device_id)'
) }}

-- 7. Пример создания Data Mart таблицы
{{ create_replicated_table(
    'dm_energy_efficiency_dashboard',
    columns=[
        {'name': 'date_key', 'type': 'Date'},
        {'name': 'region', 'type': 'String'},
        {'name': 'device_type', 'type': 'String'},
        {'name': 'avg_efficiency', 'type': 'Float64'},
        {'name': 'total_devices', 'type': 'UInt32'},
        {'name': 'dbt_updated_at', 'type': 'DateTime'}
    ],
    order_by='(date_key, region, device_type)',
    partition_by='PARTITION BY toYYYYMM(date_key)'
) }}

-- 8. Создание Distributed таблицы для Data Mart
{{ create_distributed_table(
    'dm_energy_efficiency_dashboard',
    'dm_energy_efficiency_dashboard',
    'cityHash64(region)'
) }}

-- 9. Пример использования в модели dbt
-- В файле модели можно использовать так:
/*
{{ config(
    materialized='table',
    schema='dds',
    tags=['dds', 'fact_table', 'cluster_table']
) }}

-- Создание таблицы с автоматическим _local суффиксом
{{ create_replicated_table(
    'fact_energy_consumption',
    columns=[
        {'name': 'date_key', 'type': 'Date'},
        {'name': 'device_id', 'type': 'UInt32'},
        {'name': 'total_consumption', 'Float64'}
    ],
    order_by='(date_key, device_id)',
    partition_by='PARTITION BY toYYYYMM(date_key)'
) }}

-- Затем создание Distributed таблицы
{{ create_distributed_table(
    'fact_energy_consumption',
    'fact_energy_consumption',
    'cityHash64(device_id)'
) }}
*/

-- 10. Проверка созданных таблиц
SELECT 
    'ReplicatedMergeTree Tables' as table_type,
    name as table_name,
    engine as table_engine,
    total_rows,
    total_bytes
FROM system.tables 
WHERE database = 'dds' AND name LIKE '%_local'
UNION ALL
SELECT 
    'Distributed Tables' as table_type,
    name as table_name,
    engine as table_engine,
    0 as total_rows,
    0 as total_bytes
FROM system.tables 
WHERE database = 'dds' AND name NOT LIKE '%_local' AND engine = 'Distributed'
ORDER BY table_type, table_name;
