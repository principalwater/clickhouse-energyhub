{{
  config(
    materialized='table',
    schema='cdm'
  )
}}

-- CDM слой: производительность устройств
-- Агрегированные метрики производительности для отчетности
WITH device_performance AS (
  SELECT 
    device_id,
    device_name,
    device_type,
    manufacturer,
    model,
    location_id,
    location_name,
    region,
    city,
    country,
    -- Агрегированные метрики производительности
    COUNT(*) as total_measurements,
    uniq(day_start) as active_days,
    SUM(energy_kwh) as total_energy_consumed_kwh,
    AVG(energy_kwh) as avg_energy_per_measurement_kwh,
    MAX(energy_kwh) as peak_energy_kwh,
    MIN(energy_kwh) as min_energy_kwh,
    AVG(power_factor) as avg_power_factor,
    AVG(voltage) as avg_voltage,
    AVG(current_amp) as avg_current,
    AVG(temperature) as avg_temperature,
    AVG(humidity) as avg_humidity,
    -- Метрики аномалий
    countIf(consumption_anomaly = 'high_consumption') as high_consumption_events,
    countIf(consumption_anomaly = 'low_consumption') as low_consumption_events,
    countIf(voltage_anomaly = 'voltage_anomaly') as voltage_anomaly_events,
    countIf(temperature_status = 'high_temp') as high_temp_events,
    countIf(temperature_status = 'low_temp') as low_temp_events,
    -- Временные метрики
    MIN(timestamp) as first_measurement,
    MAX(timestamp) as last_measurement,
    dateDiff('day', MIN(timestamp), MAX(timestamp)) as measurement_period_days
  FROM {{ ref('dds_energy_consumption') }}
  GROUP BY 
    device_id,
    device_name,
    device_type,
    manufacturer,
    model,
    location_id,
    location_name,
    region,
    city,
    country
)

SELECT 
  device_id,
  device_name,
  device_type,
  manufacturer,
  model,
  location_id,
  location_name,
  region,
  city,
  country,
  -- Основные метрики производительности
  total_measurements,
  active_days,
  total_energy_consumed_kwh,
  avg_energy_per_measurement_kwh,
  peak_energy_kwh,
  min_energy_kwh,
  avg_power_factor,
  avg_voltage,
  avg_current,
  avg_temperature,
  avg_humidity,
  -- Процент аномалий
  ROUND(high_consumption_events * 100.0 / total_measurements, 2) as high_consumption_percent,
  ROUND(low_consumption_events * 100.0 / total_measurements, 2) as low_consumption_percent,
  ROUND(voltage_anomaly_events * 100.0 / total_measurements, 2) as voltage_anomaly_percent,
  ROUND(high_temp_events * 100.0 / total_measurements, 2) as high_temp_percent,
  ROUND(low_temp_events * 100.0 / total_measurements, 2) as low_temp_percent,
  -- Количество аномалий
  high_consumption_events,
  low_consumption_events,
  voltage_anomaly_events,
  high_temp_events,
  low_temp_events,
  -- Временные метрики
  first_measurement,
  last_measurement,
  measurement_period_days,
  -- Вычисляемые метрики
  CASE 
    WHEN measurement_period_days > 0 THEN total_energy_consumed_kwh / measurement_period_days
    ELSE 0 
  END as avg_daily_energy_kwh,
  CASE 
    WHEN total_measurements > 0 THEN total_measurements / measurement_period_days
    ELSE 0 
  END as avg_measurements_per_day,
  -- Рейтинги производительности
  CASE 
    WHEN avg_power_factor >= 0.95 THEN 'excellent'
    WHEN avg_power_factor >= 0.9 THEN 'good'
    WHEN avg_power_factor >= 0.85 THEN 'acceptable'
    ELSE 'poor'
  END as power_factor_rating,
  CASE 
    WHEN high_consumption_percent <= 5 THEN 'excellent'
    WHEN high_consumption_percent <= 10 THEN 'good'
    WHEN high_consumption_percent <= 20 THEN 'acceptable'
    ELSE 'poor'
  END as consumption_stability_rating,
  CASE 
    WHEN voltage_anomaly_percent <= 1 THEN 'excellent'
    WHEN voltage_anomaly_percent <= 5 THEN 'good'
    WHEN voltage_anomaly_percent <= 10 THEN 'acceptable'
    ELSE 'poor'
  END as voltage_stability_rating
FROM device_performance
ORDER BY total_energy_consumed_kwh DESC
