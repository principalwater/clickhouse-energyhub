-- Marts модель для ежедневной агрегации энергопотребления
-- Основная таблица для бизнес-аналитики и KPI

{{ config(
    materialized='table',
    tags=['marts', 'energy_consumption', 'daily_aggregation'],
    -- Оптимизация для ClickHouse
    engine='MergeTree()',
    partition_by='toYYYYMM(date_key)',
    order_by='(device_id, date_key, location_id)'
) }}

SELECT 
    toDate(hour_key) as date_key,
    device_id,
    location_id,
    device_type,
    -- Ежедневные агрегаты по энергии
    sum(hourly_energy_kwh) as daily_energy_kwh,
    avg(avg_hourly_energy_kwh) as avg_daily_energy_kwh,
    max(max_hourly_energy_kwh) as peak_hourly_energy_kwh,
    min(min_hourly_energy_kwh) as min_hourly_energy_kwh,
    -- Ежедневные агрегаты по мощности
    avg(avg_apparent_power_kva) as avg_daily_apparent_power_kva,
    max(max_apparent_power_kva) as peak_daily_apparent_power_kva,
    -- Статистика
    sum(readings_count) as total_readings,
    count(*) as hours_with_data,
    -- Эффективность (часы с данными / 24)
    round(count(*) * 100.0 / 24, 2) as data_completeness_percent,
    -- Метаданные
    min(dbt_loaded_at) as dbt_loaded_at,
    now() as dbt_updated_at
FROM {{ ref('int_energy_hourly') }}
GROUP BY date_key, device_id, location_id, device_type
