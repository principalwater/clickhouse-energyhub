-- Скрипт для создания кластерных таблиц
-- ClickHouse EnergyHub - Кластер dwh_prod
--
-- ЛОГИКА ИМЕНОВАНИЯ КЛАСТЕРНЫХ ТАБЛИЦ:
-- 1. ReplicatedMergeTree таблицы создаются с суффиксом _local
-- 2. Distributed таблицы имеют то же имя, что и основная таблица (без _local)
-- 3. Путь для ReplicatedMergeTree: /clickhouse/tables/{shard}/otus_default/{table_name}_local/{uuid}
-- 4. База данных otus_default создается автоматически
-- 5. Distributed таблицы ссылаются на _local таблицы в базе otus_default
--
-- Пример:
-- - ReplicatedMergeTree: dim_locations_local
-- - Distributed: dim_locations (ссылается на dim_locations_local)
-- - Путь: /clickhouse/tables/{shard}/otus_default/dim_locations_local/{uuid}

-- 1. Создание ReplicatedMergeTree таблиц на кластере

-- Создание основной базы данных
CREATE DATABASE IF NOT EXISTS otus_default ON CLUSTER dwh_prod;

-- Dimension таблица локаций
CREATE TABLE IF NOT EXISTS dds.dim_locations_local ON CLUSTER dwh_prod (
    location_id UInt32,
    location_name String,
    region String,
    city String,
    timezone String,
    latitude Float64,
    longitude Float64,
    address String,
    postal_code String,
    country String,
    location_type String,
    business_status String,
    has_coordinates UInt8,
    has_address UInt8,
    created_at DateTime,
    updated_at DateTime,
    dbt_updated_at DateTime
) ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/otus_default/dim_locations_local/{{ uuid() }}', '{replica}')
ORDER BY location_id
PARTITION BY toYYYYMM(created_at)
SETTINGS 
    replication_alter_partitions_sync = 2,
    compression_codec = 'ZSTD(3)';

-- Fact таблица потребления энергии
CREATE TABLE IF NOT EXISTS dds.fact_energy_consumption_local ON CLUSTER dwh_prod (
    date_key Date,
    hour_key UInt8,
    device_id UInt32,
    location_id UInt32,
    device_type String,
    region String,
    city String,
    country String,
    time_period String,
    season String,
    measurement_count UInt32,
    avg_consumption Float64,
    total_consumption Float64,
    max_consumption Float64,
    min_consumption Float64,
    avg_voltage Float64,
    avg_current Float64,
    avg_power_factor Float64,
    avg_apparent_power Float64,
    avg_real_power Float64,
    avg_reactive_power Float64,
    avg_normalized_consumption Float64,
    consumption_stddev Float64,
    consumption_95th_percentile Float64,
    first_measurement_time DateTime,
    last_measurement_time DateTime,
    dbt_updated_at DateTime
) ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/otus_default/fact_energy_consumption_local/{{ uuid() }}', '{replica}')
ORDER BY (date_key, hour_key, device_id, location_id)
PARTITION BY toYYYYMM(date_key)
SETTINGS 
    replication_alter_partitions_sync = 2,
    compression_codec = 'ZSTD(3)';

-- Data Mart ежедневной сводки
CREATE TABLE IF NOT EXISTS data_marts.daily_energy_summary_local ON CLUSTER dwh_prod (
    date_key Date,
    region String,
    city String,
    country String,
    device_type String,
    time_period String,
    season String,
    active_devices UInt32,
    active_locations UInt32,
    total_measurements UInt32,
    daily_total_consumption Float64,
    daily_avg_consumption Float64,
    daily_peak_consumption Float64,
    daily_min_consumption Float64,
    daily_avg_voltage Float64,
    daily_avg_current Float64,
    daily_avg_power_factor Float64,
    daily_avg_real_power Float64,
    daily_avg_apparent_power Float64,
    daily_avg_reactive_power Float64,
    daily_consumption_stddev Float64,
    daily_consumption_95th_percentile Float64,
    power_efficiency_rating String,
    consumption_level String,
    data_volatility String,
    avg_consumption_per_device_hour Float64,
    day_start_time DateTime,
    day_end_time DateTime,
    dbt_updated_at DateTime
) ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/otus_default/daily_energy_summary_local/{{ uuid() }}', '{replica}')
ORDER BY (date_key, region, city, device_type)
PARTITION BY toYYYYMM(date_key)
SETTINGS 
    replication_alter_partitions_sync = 2,
    compression_codec = 'ZSTD(3)';

-- 2. Создание Distributed таблиц для распределенных операций

-- Distributed таблица для dim_locations
CREATE TABLE IF NOT EXISTS dds.dim_locations ON CLUSTER dwh_prod AS dds.dim_locations_local
ENGINE = Distributed(dwh_prod, otus_default, dim_locations_local, cityHash64(location_id));

-- Distributed таблица для fact_energy_consumption
CREATE TABLE IF NOT EXISTS dds.fact_energy_consumption ON CLUSTER dwh_prod AS dds.fact_energy_consumption_local
ENGINE = Distributed(dwh_prod, otus_default, fact_energy_consumption_local, cityHash64(device_id));

-- Distributed таблица для daily_energy_summary
CREATE TABLE IF NOT EXISTS data_marts.daily_energy_summary ON CLUSTER dwh_prod AS data_marts.daily_energy_summary_local
ENGINE = Distributed(dwh_prod, otus_default, daily_energy_summary_local, cityHash64(region));

-- 3. Создание индексов для оптимизации

-- Индексы для dim_locations
ALTER TABLE dds.dim_locations_local ON CLUSTER dwh_prod 
ADD INDEX idx_location_id location_id TYPE minmax GRANULARITY 1;

ALTER TABLE dds.dim_locations_local ON CLUSTER dwh_prod 
ADD INDEX idx_region_city region, city TYPE set(1000) GRANULARITY 1;

ALTER TABLE dds.dim_locations_local ON CLUSTER dwh_prod 
ADD INDEX idx_country country TYPE set(100) GRANULARITY 1;

-- Индексы для fact_energy_consumption
ALTER TABLE dds.fact_energy_consumption_local ON CLUSTER dwh_prod 
ADD INDEX idx_date_key date_key TYPE minmax GRANULARITY 1;

ALTER TABLE dds.fact_energy_consumption_local ON CLUSTER dwh_prod 
ADD INDEX idx_device_location device_id, location_id TYPE minmax GRANULARITY 1;

ALTER TABLE dds.fact_energy_consumption_local ON CLUSTER dwh_prod 
ADD INDEX idx_device_type device_type TYPE set(10) GRANULARITY 1;

-- Индексы для daily_energy_summary
ALTER TABLE data_marts.daily_energy_summary_local ON CLUSTER dwh_prod 
ADD INDEX idx_date_region date_key, region TYPE minmax GRANULARITY 1;

ALTER TABLE data_marts.daily_energy_summary_local ON CLUSTER dwh_prod 
ADD INDEX idx_device_type device_type TYPE set(10) GRANULARITY 1;

-- 4. Проверка создания таблиц

SELECT 
    'dim_locations_local' as table_name,
    count() as replicas_count,
    sum(total_rows) as total_rows,
    sum(total_bytes) as total_bytes
FROM system.replicas 
WHERE database = 'dds' AND table = 'dim_locations_local'
UNION ALL
SELECT 
    'fact_energy_consumption_local' as table_name,
    count() as replicas_count,
    sum(total_rows) as total_rows,
    sum(total_bytes) as total_bytes
FROM system.replicas 
WHERE database = 'dds' AND table = 'fact_energy_consumption_local'
UNION ALL
SELECT 
    'daily_energy_summary_local' as table_name,
    count() as replicas_count,
    sum(total_rows) as total_rows,
    sum(total_bytes) as total_bytes
FROM system.replicas 
WHERE database = 'data_marts' AND table = 'daily_energy_summary_local'
ORDER BY table_name;
