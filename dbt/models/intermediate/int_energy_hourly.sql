-- Intermediate модель для почасовой агрегации энергопотребления
-- Агрегация данных по часам для оптимизации производительности

{{ config(
    materialized='view',
    tags=['intermediate', 'energy_consumption', 'hourly_aggregation']
) }}

SELECT 
    toStartOfHour(timestamp) as hour_key,
    device_id,
    location_id,
    device_type,
    -- Агрегаты по энергии
    sum(energy_kwh_validated) as hourly_energy_kwh,
    avg(energy_kwh_validated) as avg_hourly_energy_kwh,
    max(energy_kwh_validated) as max_hourly_energy_kwh,
    min(energy_kwh_validated) as min_hourly_energy_kwh,
    -- Агрегаты по мощности
    avg(apparent_power_kva) as avg_apparent_power_kva,
    max(apparent_power_kva) as max_apparent_power_kva,
    -- Статистика
    count(*) as readings_count,
    -- Метаданные
    min(dbt_loaded_at) as dbt_loaded_at,
    now() as dbt_updated_at
FROM {{ ref('stg_energy_consumption') }}
GROUP BY hour_key, device_id, location_id, device_type
