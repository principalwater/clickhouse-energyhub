{{
  config(
    materialized='table',
    schema='dds'
  )
}}

-- DDS слой: детальные данные об энергопотреблении
-- Полные DQ проверки и детализация до уровня события
WITH enhanced_data AS (
  SELECT 
    ec.device_id as device_id,
    ec.location_id as location_id,
    ec.timestamp as timestamp,
    ec.energy_kwh as energy_kwh,
    ec.voltage as voltage,
    ec.current_amp as current_amp,
    ec.power_factor as power_factor,
    ec.temperature as temperature,
    ec.humidity as humidity,
    ec.calculated_power_w as calculated_power_w,
    ec.temperature_status as temperature_status,
    ec.humidity_status as humidity_status,
    ec.inserted_at as inserted_at,
    ec.source as source,
    -- Добавляем данные об устройстве
    d.device_name,
    d.device_type,
    d.device_category,
    d.manufacturer,
    d.model,
    d.status as device_status,
    d.maintenance_status as device_maintenance_status,
    -- Добавляем данные о локации
    l.location_name,
    l.region,
    l.city,
    l.country,
    l.location_type,
    l.region_category,
    l.timezone_offset_hours,
    -- Вычисляем дополнительные метрики
    ec.energy_kwh * 1000 as energy_wh,  -- Конвертируем в ватт-часы
    ec.voltage * ec.current_amp as apparent_power_va,  -- Полная мощность
    ec.calculated_power_w / (ec.voltage * ec.current_amp) as actual_power_factor,  -- Фактический коэффициент мощности
    -- Аномалии
    CASE 
      WHEN ec.energy_kwh > 200 THEN 'high_consumption'
      WHEN ec.energy_kwh < 10 THEN 'low_consumption'
      ELSE 'normal_consumption'
    END as consumption_anomaly,
    CASE 
      WHEN ec.voltage > 240 OR ec.voltage < 200 THEN 'voltage_anomaly'
      ELSE 'normal_voltage'
    END as voltage_anomaly,
    -- Временные метрики
    toStartOfHour(ec.timestamp) as hour_start,
    toStartOfDay(ec.timestamp) as day_start,
    toStartOfMonth(ec.timestamp) as month_start,
    toDayOfWeek(ec.timestamp) as day_of_week,
    toHour(ec.timestamp) as hour_of_day
  FROM {{ ref('ods_energy_consumption') }} ec
  LEFT JOIN {{ ref('ods_devices') }} d ON ec.device_id = d.device_id
  LEFT JOIN {{ ref('ods_locations') }} l ON ec.location_id = l.location_id
  WHERE 
    -- Дополнительные DQ проверки для DDS
    ec.device_id IS NOT NULL
    AND ec.location_id IS NOT NULL
    AND ec.timestamp IS NOT NULL
    AND ec.energy_kwh IS NOT NULL
    AND ec.voltage IS NOT NULL
    AND ec.current_amp IS NOT NULL
    AND d.device_id IS NOT NULL  -- Устройство должно существовать
    AND l.location_id IS NOT NULL  -- Локация должна существовать
    AND d.status = 'active'  -- Только активные устройства
)

SELECT 
  device_id,
  location_id,
  timestamp,
  energy_kwh,
  energy_wh,
  voltage,
  current_amp,
  power_factor,
  actual_power_factor,
  apparent_power_va,
  calculated_power_w,
  temperature,
  humidity,
  temperature_status,
  humidity_status,
  consumption_anomaly,
  voltage_anomaly,
  -- Данные об устройстве
  device_name,
  device_type,
  device_category,
  manufacturer,
  model,
  device_status,
  device_maintenance_status,
  -- Данные о локации
  location_name,
  region,
  city,
  country,
  location_type,
  region_category,
  timezone_offset_hours,
  -- Временные метрики
  hour_start,
  day_start,
  month_start,
  day_of_week,
  hour_of_day,
  -- Системные поля
  inserted_at,
  source
FROM enhanced_data ec
ORDER BY device_id, timestamp
