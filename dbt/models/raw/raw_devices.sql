{{
  config(
    materialized='table',
    schema='raw',
    tags=['raw']
  )
}}

-- Raw слой: сырые данные об устройствах
SELECT 
  device_id,
  device_name,
  device_type,
  location_id,
  manufacturer,
  model,
  installation_date,
  last_maintenance_date,
  status,
  raw_data,
  -- Добавляем метаданные
  now() as inserted_at,
  'raw_data' as source
FROM {{ source('raw', 'devices_raw') }}
