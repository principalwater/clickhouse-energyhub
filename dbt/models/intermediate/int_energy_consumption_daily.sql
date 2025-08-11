{{
  config(
    materialized='incremental',
    schema='intermediate',
    tags=['intermediate', 'energy_consumption', 'daily_aggregation'],
    unique_key=['date_key', 'device_id', 'location_id'],
    incremental_strategy='merge'
  )
}}

-- Промежуточная модель для ежедневного потребления энергии
-- Агрегация почасовых данных для Data Marts

WITH daily_aggregation AS (
  SELECT 
    date_key,
    device_id,
    location_id,
    device_type,
    device_name,
    device_status,
    region,
    city,
    country,
    timezone,
    time_period,
    season,
    -- Агрегация по дням
    sum(measurement_count) as daily_measurement_count,
    avg(avg_consumption) as daily_avg_consumption,
    sum(total_consumption) as daily_total_consumption,
    max(max_consumption) as daily_peak_consumption,
    min(min_consumption) as daily_min_consumption,
    avg(avg_voltage) as daily_avg_voltage,
    avg(avg_current) as daily_avg_current,
    avg(avg_power_factor) as daily_avg_power_factor,
    avg(avg_apparent_power) as daily_avg_apparent_power,
    avg(avg_real_power) as daily_avg_real_power,
    avg(avg_reactive_power) as daily_avg_reactive_power,
    avg(normalized_consumption) as daily_avg_normalized_consumption,
    -- Статистика по дням
    avg(consumption_stddev) as daily_consumption_stddev,
    avg(consumption_95th_percentile) as daily_consumption_95th_percentile,
    -- Временные метки
    min(first_measurement_time) as day_start_time,
    max(last_measurement_time) as day_end_time,
    -- DQ score
    avg(dq_score) as daily_dq_score
  FROM {{ ref('int_energy_consumption_hourly') }}
  WHERE date_key >= now() - INTERVAL 90 DAY  -- Данные за последние 3 месяца
  GROUP BY 
    date_key, device_id, location_id, device_type, device_name, device_status,
    region, city, country, timezone, time_period, season
),

-- Расчет дополнительных метрик
enriched_daily AS (
  SELECT 
    *,
    -- Уровень потребления
    CASE 
      WHEN daily_total_consumption < 1000 THEN 'low'
      WHEN daily_total_consumption < 10000 THEN 'medium'
      WHEN daily_total_consumption < 100000 THEN 'high'
      ELSE 'very_high'
    END as consumption_level,
    
    -- Волатильность данных
    CASE 
      WHEN daily_consumption_stddev < 100 THEN 'low'
      WHEN daily_consumption_stddev < 1000 THEN 'medium'
      ELSE 'high'
    END as data_volatility,
    
    -- Эффективность по дням
    CASE 
      WHEN daily_avg_power_factor >= 0.9 THEN 'excellent'
      WHEN daily_avg_power_factor >= 0.8 THEN 'good'
      WHEN daily_avg_power_factor >= 0.7 THEN 'fair'
      ELSE 'poor'
    END as daily_efficiency_rating,
    
    -- Среднее потребление на устройство в час
    daily_total_consumption / 24.0 as avg_consumption_per_device_hour,
    
    -- Процент активных часов
    CASE 
      WHEN daily_measurement_count >= 20 THEN 'high_activity'
      WHEN daily_measurement_count >= 10 THEN 'medium_activity'
      ELSE 'low_activity'
    END as activity_level
  FROM daily_aggregation
),

-- Финальная обработка с бизнес-логикой
final_daily AS (
  SELECT 
    *,
    -- Бизнес-правила
    CASE 
      WHEN daily_avg_voltage > 0 AND daily_avg_current > 0 THEN 1 
      WHEN daily_avg_voltage = 0 AND daily_avg_current = 0 THEN 1
      ELSE 0 
    END as voltage_current_consistency,
    
    CASE 
      WHEN daily_total_consumption >= 0 THEN 1 
      ELSE 0 
    END as consumption_validity,
    
    CASE 
      WHEN daily_measurement_count > 0 THEN 1 
      ELSE 0 
    END as measurement_validity,
    
    -- Финальный DQ score
    (voltage_current_consistency + consumption_validity + measurement_validity + 
     CASE WHEN daily_dq_score >= 0.8 THEN 1 ELSE 0 END) / 4.0 as final_dq_score
  FROM enriched_daily
)

SELECT 
  date_key,
  device_id,
  location_id,
  device_type,
  device_name,
  device_status,
  region,
  city,
  country,
  timezone,
  time_period,
  season,
  daily_measurement_count,
  daily_avg_consumption,
  daily_total_consumption,
  daily_peak_consumption,
  daily_min_consumption,
  daily_avg_voltage,
  daily_avg_current,
  daily_avg_power_factor,
  daily_avg_apparent_power,
  daily_avg_real_power,
  daily_avg_reactive_power,
  daily_avg_normalized_consumption,
  daily_consumption_stddev,
  daily_consumption_95th_percentile,
  daily_efficiency_rating,
  consumption_level,
  data_volatility,
  activity_level,
  avg_consumption_per_device_hour,
  day_start_time,
  day_end_time,
  final_dq_score,
  now() as dbt_updated_at
FROM final_daily
WHERE final_dq_score >= 0.8  -- Строгий фильтр по качеству для Data Marts

{% if is_incremental() %}
  -- Инкрементальная загрузка
  AND date_key >= (SELECT max(date_key) FROM {{ this }})
{% endif %}
