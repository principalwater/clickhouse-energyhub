{{
  config(
    materialized='table',
    schema='dds',
    tags=['dds', 'fact', 'energy_consumption'],
    indexes=[
      {'columns': ['timestamp'], 'type': 'minmax'},
      {'columns': ['device_id'], 'type': 'minmax'},
      {'columns': ['location_id'], 'type': 'minmax'},
      {'columns': ['date_key'], 'type': 'minmax'}
    ]
  )
}}

-- Fact таблица для потребления энергии в DDS слое
-- Агрегированные данные об энергопотреблении с бизнес-логикой

WITH staging_measurements AS (
  SELECT 
    id,
    timestamp,
    energy_consumption,
    voltage,
    current,
    power_factor,
    device_id,
    location_id,
    created_at,
    updated_at
  FROM {{ ref('stg_energy_measurements') }}
  WHERE dq_score >= 0.8  -- Только качественные данные
),

-- Обогащение данными об устройствах и локациях
enriched_measurements AS (
  SELECT 
    m.*,
    d.device_name,
    d.device_type,
    d.manufacturer,
    d.status as device_status,
    l.region,
    l.city,
    l.country,
    l.timezone,
    
    -- Временные ключи для аналитики
    toDate(timestamp) as date_key,
    toHour(timestamp) as hour_key,
    toMinute(timestamp) as minute_key,
    
    -- Расчетные поля
    voltage * current as apparent_power,
    voltage * current * power_factor as real_power,
    CASE 
      WHEN power_factor > 0 THEN (voltage * current * (1 - power_factor)) / 1000
      ELSE 0 
    END as reactive_power_kvar,
    
    -- Нормализация энергопотребления
    CASE 
      WHEN device_type = 'sensor' THEN energy_consumption
      WHEN device_type = 'meter' THEN energy_consumption * 1.0
      WHEN device_type = 'controller' THEN energy_consumption * 0.8
      ELSE energy_consumption
    END as normalized_consumption,
    
    -- Классификация по времени суток
    CASE 
      WHEN toHour(timestamp) BETWEEN 6 AND 22 THEN 'День'
      ELSE 'Ночь'
    END as time_period,
    
    -- Классификация по сезону
    CASE 
      WHEN toMonth(timestamp) IN (12, 1, 2) THEN 'Зима'
      WHEN toMonth(timestamp) IN (3, 4, 5) THEN 'Весна'
      WHEN toMonth(timestamp) IN (6, 7, 8) THEN 'Лето'
      ELSE 'Осень'
    END as season
    
  FROM staging_measurements m
  LEFT JOIN {{ ref('stg_devices') }} d ON m.device_id = d.device_id
  LEFT JOIN {{ ref('stg_locations') }} l ON m.location_id = l.location_id
),

-- Агрегация по временным интервалам
time_aggregated AS (
  SELECT 
    date_key,
    hour_key,
    device_id,
    location_id,
    device_type,
    region,
    city,
    country,
    time_period,
    season,
    
    -- Агрегированные метрики
    COUNT(*) as measurement_count,
    AVG(energy_consumption) as avg_consumption,
    SUM(energy_consumption) as total_consumption,
    MAX(energy_consumption) as max_consumption,
    MIN(energy_consumption) as min_consumption,
    
    AVG(voltage) as avg_voltage,
    AVG(current) as avg_current,
    AVG(power_factor) as avg_power_factor,
    
    AVG(apparent_power) as avg_apparent_power,
    AVG(real_power) as avg_real_power,
    AVG(reactive_power_kvar) as avg_reactive_power,
    
    AVG(normalized_consumption) as avg_normalized_consumption,
    
    -- Статистические метрики
    stddevPop(energy_consumption) as consumption_stddev,
    quantile(0.95)(energy_consumption) as consumption_95th_percentile,
    
    -- Временные метрики
    MIN(timestamp) as first_measurement_time,
    MAX(timestamp) as last_measurement_time,
    
    -- Системные поля
    now() as dbt_updated_at
    
  FROM enriched_measurements
  
  GROUP BY 
    date_key, hour_key, device_id, location_id, device_type, 
    region, city, country, time_period, season
)

SELECT 
  -- Ключи
  date_key,
  hour_key,
  device_id,
  location_id,
  
  -- Атрибуты
  device_type,
  region,
  city,
  country,
  time_period,
  season,
  
  -- Метрики потребления
  measurement_count,
  ROUND(avg_consumption, 4) as avg_consumption,
  ROUND(total_consumption, 4) as total_consumption,
  ROUND(max_consumption, 4) as max_consumption,
  ROUND(min_consumption, 4) as min_consumption,
  
  -- Метрики электрических параметров
  ROUND(avg_voltage, 2) as avg_voltage,
  ROUND(avg_current, 2) as avg_current,
  ROUND(avg_power_factor, 4) as avg_power_factor,
  
  ROUND(avg_apparent_power, 2) as avg_apparent_power,
  ROUND(avg_real_power, 2) as avg_real_power,
  ROUND(avg_reactive_power, 4) as avg_reactive_power,
  
  ROUND(avg_normalized_consumption, 4) as avg_normalized_consumption,
  
  -- Статистические метрики
  ROUND(consumption_stddev, 4) as consumption_stddev,
  ROUND(consumption_95th_percentile, 4) as consumption_95th_percentile,
  
  -- Временные метрики
  first_measurement_time,
  last_measurement_time,
  
  -- Системные поля
  dbt_updated_at

FROM time_aggregated

ORDER BY date_key DESC, hour_key DESC, device_id, location_id
