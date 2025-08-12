{{
  config(
    materialized='table',
    schema='cdm'
  )
}}

-- CDM слой: ежедневная агрегация энергопотребления
-- Агрегированные витрины для отчетности и дашбордов
WITH daily_aggregation AS (
  SELECT 
    day_start as date,
    device_id,
    location_id,
    device_name,
    device_type,
    manufacturer,
    location_name,
    region,
    city,
    country,
    -- Агрегированные метрики
    COUNT(*) as measurements_count,
    SUM(energy_kwh) as total_energy_kwh,
    AVG(energy_kwh) as avg_energy_kwh,
    MIN(energy_kwh) as min_energy_kwh,
    MAX(energy_kwh) as max_energy_kwh,
    AVG(voltage) as avg_voltage,
    AVG(current_amp) as avg_current,
    AVG(power_factor) as avg_power_factor,
    AVG(temperature) as avg_temperature,
    AVG(humidity) as avg_humidity,
    -- Аномалии
    countIf(consumption_anomaly = 'high_consumption') as high_consumption_count,
    countIf(consumption_anomaly = 'low_consumption') as low_consumption_count,
    countIf(voltage_anomaly = 'voltage_anomaly') as voltage_anomaly_count,
    countIf(temperature_status = 'high_temp') as high_temp_count,
    countIf(temperature_status = 'low_temp') as low_temp_count,
    -- Временные метрики
    toDayOfWeek(day_start) as day_of_week,
    toMonth(day_start) as month,
    toYear(day_start) as year
  FROM {{ ref('dds_energy_consumption') }}
  GROUP BY 
    day_start,
    device_id,
    location_id,
    device_name,
    device_type,
    manufacturer,
    location_name,
    region,
    city,
    country
)

SELECT 
  date,
  device_id,
  location_id,
  device_name,
  device_type,
  manufacturer,
  location_name,
  region,
  city,
  country,
  -- Основные метрики
  measurements_count,
  total_energy_kwh,
  avg_energy_kwh,
  min_energy_kwh,
  max_energy_kwh,
  avg_voltage,
  avg_current,
  avg_power_factor,
  avg_temperature,
  avg_humidity,
  -- Процент аномалий
  ROUND(high_consumption_count * 100.0 / measurements_count, 2) as high_consumption_percent,
  ROUND(low_consumption_count * 100.0 / measurements_count, 2) as low_consumption_percent,
  ROUND(voltage_anomaly_count * 100.0 / measurements_count, 2) as voltage_anomaly_percent,
  ROUND(high_temp_count * 100.0 / measurements_count, 2) as high_temp_percent,
  ROUND(low_temp_count * 100.0 / measurements_count, 2) as low_temp_percent,
  -- Количество аномалий
  high_consumption_count,
  low_consumption_count,
  voltage_anomaly_count,
  high_temp_count,
  low_temp_count,
  -- Временные метрики
  day_of_week,
  month,
  year,
  -- Категории
  CASE 
    WHEN day_of_week IN (6, 7) THEN 'weekend'
    ELSE 'weekday'
  END as day_category,
  CASE 
    WHEN month IN (12, 1, 2) THEN 'winter'
    WHEN month IN (3, 4, 5) THEN 'spring'
    WHEN month IN (6, 7, 8) THEN 'summer'
    ELSE 'autumn'
  END as season
FROM daily_aggregation
ORDER BY date DESC, device_id
