{{
  config(
    materialized='table',
    schema='ods',
    tags=['ods']
  )
}}

-- ODS слой: предочищенные данные об энергопотреблении
-- Базовые DQ проверки и очистка данных
WITH cleaned_data AS (
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
    inserted_at,
    source
  FROM {{ ref('raw_energy_consumption') }}
  WHERE 
    -- Базовые DQ проверки
    device_id IS NOT NULL 
    AND location_id IS NOT NULL 
    AND timestamp IS NOT NULL
    AND energy_kwh > 0  -- Энергия должна быть положительной
    AND voltage BETWEEN 180 AND 250  -- Нормальный диапазон напряжения
    AND current_amp > 0  -- Ток должен быть положительным
    AND power_factor BETWEEN 0.5 AND 1.0  -- Коэффициент мощности в разумных пределах
    AND temperature BETWEEN -50 AND 100  -- Температура в разумных пределах
    AND humidity BETWEEN 0 AND 100  -- Влажность в процентах
)

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
  inserted_at,
  source,
  -- Добавляем вычисляемые поля
  energy_kwh * voltage * current_amp * power_factor as calculated_power_w,
  CASE 
    WHEN temperature > 80 THEN 'high_temp'
    WHEN temperature < 0 THEN 'low_temp'
    ELSE 'normal_temp'
  END as temperature_status,
  CASE 
    WHEN humidity > 80 THEN 'high_humidity'
    WHEN humidity < 20 THEN 'low_humidity'
    ELSE 'normal_humidity'
  END as humidity_status
FROM cleaned_data
