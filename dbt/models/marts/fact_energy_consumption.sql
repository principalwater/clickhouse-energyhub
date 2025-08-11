{{
  config(
    materialized='table',
    schema='marts',
    engine='MergeTree()',
    order_by='timestamp',
    partition_by='toYYYYMM(timestamp)',
    tags=['marts', 'fact', 'energy_consumption']
  )
}}

-- Фактовая таблица потребления энергии
-- Эта модель агрегирует данные потребления энергии по различным измерениям

WITH staging_data AS (
  SELECT 
    id,
    timestamp,
    energy_consumption,
    voltage,
    current,
    power_factor,
    device_id,
    location_id,
    dq_score,
    created_at,
    updated_at
  FROM {{ ref('stg_energy_data') }}
  WHERE dq_score >= 0.8  -- Только данные с высоким качеством
),

device_info AS (
  SELECT 
    device_id,
    device_type_id,
    device_name,
    power_rating_max,
    voltage_standard
  FROM {{ ref('dim_devices') }}
),

location_info AS (
  SELECT 
    location_id,
    location_name,
    region,
    city,
    timezone
  FROM {{ ref('dim_locations') }}
),

-- Агрегация по часам
hourly_consumption AS (
  SELECT 
    toStartOfHour(timestamp) as hour_timestamp,
    device_id,
    location_id,
    COUNT(*) as measurement_count,
    AVG(energy_consumption) as avg_energy_consumption,
    SUM(energy_consumption) as total_energy_consumption,
    AVG(voltage) as avg_voltage,
    AVG(current) as avg_current,
    AVG(power_factor) as avg_power_factor,
    AVG(dq_score) as avg_dq_score,
    MIN(energy_consumption) as min_energy_consumption,
    MAX(energy_consumption) as max_energy_consumption,
    STDDEV(energy_consumption) as stddev_energy_consumption
  FROM staging_data
  GROUP BY hour_timestamp, device_id, location_id
),

-- Агрегация по дням
daily_consumption AS (
  SELECT 
    toDate(timestamp) as date_timestamp,
    device_id,
    location_id,
    COUNT(*) as measurement_count,
    AVG(energy_consumption) as avg_energy_consumption,
    SUM(energy_consumption) as total_energy_consumption,
    AVG(voltage) as avg_voltage,
    AVG(current) as avg_current,
    AVG(power_factor) as avg_power_factor,
    AVG(dq_score) as avg_dq_score,
    MIN(energy_consumption) as min_energy_consumption,
    MAX(energy_consumption) as max_energy_consumption,
    STDDEV(energy_consumption) as stddev_energy_consumption
  FROM staging_data
  GROUP BY date_timestamp, device_id, location_id
)

-- Основной результат - почасовые данные
SELECT 
  h.hour_timestamp as timestamp,
  h.device_id,
  h.location_id,
  
  -- Информация об устройстве
  d.device_type_id,
  d.device_name,
  d.power_rating_max,
  d.voltage_standard,
  
  -- Информация о локации
  l.location_name,
  l.region,
  l.city,
  l.timezone,
  
  -- Метрики потребления
  h.measurement_count,
  h.avg_energy_consumption,
  h.total_energy_consumption,
  h.avg_voltage,
  h.avg_current,
  h.avg_power_factor,
  
  -- DQ метрики
  h.avg_dq_score,
  
  -- Статистические метрики
  h.min_energy_consumption,
  h.max_energy_consumption,
  h.stddev_energy_consumption,
  
  -- Дополнительные расчеты
  h.total_energy_consumption * 1000 as total_energy_wh,  -- В ватт-часах
  h.avg_energy_consumption * 24 as estimated_daily_consumption,  -- Оценка дневного потребления
  
  -- Временные метрики
  toHour(h.hour_timestamp) as hour_of_day,
  toDayOfWeek(h.hour_timestamp) as day_of_week,
  toMonth(h.hour_timestamp) as month,
  toYear(h.hour_timestamp) as year,
  
  -- Системные поля
  now() as created_at,
  now() as updated_at,
  '{{ invocation_id }}' as dbt_run_id

FROM hourly_consumption h
LEFT JOIN device_info d ON h.device_id = d.device_id
LEFT JOIN location_info l ON h.location_id = l.location_id

-- Фильтр по качеству данных
WHERE h.avg_dq_score >= 0.8

ORDER BY h.hour_timestamp DESC, h.device_id, h.location_id
