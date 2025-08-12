{{
  config(
    materialized='table',
    schema='ods'
  )
}}

-- ODS слой: предочищенные данные об устройствах
-- Базовые DQ проверки и очистка данных
WITH cleaned_data AS (
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
    inserted_at,
    source
  FROM {{ ref('raw_devices') }}
  WHERE 
    -- Базовые DQ проверки
    device_id IS NOT NULL 
    AND device_name IS NOT NULL 
    AND device_type IS NOT NULL
    AND location_id IS NOT NULL
    AND manufacturer IS NOT NULL
    AND model IS NOT NULL
    AND installation_date IS NOT NULL
    AND status IN ('active', 'inactive', 'maintenance', 'error')  -- Валидные статусы
)

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
  inserted_at,
  source,
  -- Добавляем вычисляемые поля
  CASE 
    WHEN device_type IN ('electricity_meter', 'solar_panel', 'wind_turbine') THEN 'energy_generation'
    WHEN device_type = 'battery' THEN 'energy_storage'
    ELSE 'other'
  END as device_category,
  CASE 
    WHEN last_maintenance_date < now() - INTERVAL 1 YEAR THEN 'maintenance_overdue'
    WHEN last_maintenance_date < now() - INTERVAL 6 MONTH THEN 'maintenance_due_soon'
    ELSE 'maintenance_ok'
  END as maintenance_status,
  dateDiff('day', installation_date, now()) as days_since_installation
FROM cleaned_data
