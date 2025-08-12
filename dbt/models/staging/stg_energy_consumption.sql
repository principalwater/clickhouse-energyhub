-- Staging модель для энергопотребления
-- Очистка и валидация сырых данных

{{ config(
    materialized='view',
    tags=['staging', 'energy_consumption']
) }}

SELECT 
    device_id,
    timestamp,
    energy_kwh,
    location_id,
    device_type,
    voltage_v,
    current_a,
    power_factor,
    -- Валидация данных
    CASE 
        WHEN energy_kwh < 0 THEN 0 
        WHEN energy_kwh > 1000 THEN 1000
        ELSE energy_kwh 
    END as energy_kwh_validated,
    -- Дополнительные вычисления
    voltage_v * current_a / 1000 as apparent_power_kva,
    -- Метаданные
    _timestamp as dbt_loaded_at,
    now() as dbt_updated_at
FROM {{ source('raw', 'energy_consumption') }}
WHERE timestamp >= '{{ var("start_date", "2024-01-01") }}'
  AND energy_kwh IS NOT NULL
  AND device_id IS NOT NULL
  AND location_id IS NOT NULL
