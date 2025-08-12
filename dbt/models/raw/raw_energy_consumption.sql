{{
  config(
    materialized='table',
    schema='raw'
  )
}}

-- Raw слой: сырые данные об энергопотреблении
-- Этот слой содержит данные как есть, без изменений
SELECT 
  device_id,
  location_id,
  timestamp,
  energy_kwh,
  voltage,
  current_amp,
  power_factor,
  temperature,
  humidity,
  raw_data,
  -- Добавляем метаданные
  now() as inserted_at,
  'raw_data' as source
FROM {{ source('raw', 'energy_consumption_raw') }}
