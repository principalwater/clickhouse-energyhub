{{
  config(
    materialized='incremental',
    schema='intermediate',
    tags=['intermediate', 'energy_consumption', 'regional_aggregation'],
    unique_key=['date_key', 'region', 'city', 'country'],
    incremental_strategy='merge'
  )
}}

-- Промежуточная модель для регионального потребления энергии
-- Агрегация по географическим зонам для анализа трендов

WITH regional_aggregation AS (
  SELECT 
    date_key,
    region,
    city,
    country,
    timezone,
    time_period,
    season,
    -- Агрегация по регионам
    count(DISTINCT device_id) as active_devices,
    count(DISTINCT location_id) as active_locations,
    sum(daily_measurement_count) as total_measurements,
    sum(daily_total_consumption) as regional_total_consumption,
    avg(daily_avg_consumption) as regional_avg_consumption,
    max(daily_peak_consumption) as regional_peak_consumption,
    min(daily_min_consumption) as regional_min_consumption,
    avg(daily_avg_voltage) as regional_avg_voltage,
    avg(daily_avg_current) as regional_avg_current,
    avg(daily_avg_power_factor) as regional_avg_power_factor,
    avg(daily_avg_apparent_power) as regional_avg_apparent_power,
    avg(daily_avg_real_power) as regional_avg_real_power,
    avg(daily_avg_reactive_power) as regional_avg_reactive_power,
    avg(daily_avg_normalized_consumption) as regional_avg_normalized_consumption,
    -- Статистика по регионам
    avg(daily_consumption_stddev) as regional_consumption_stddev,
    avg(daily_consumption_95th_percentile) as regional_consumption_95th_percentile,
    -- Временные метки
    min(day_start_time) as regional_day_start,
    max(day_end_time) as regional_day_end,
    -- DQ score
    avg(final_dq_score) as regional_dq_score
  FROM {{ ref('int_energy_consumption_daily') }}
  WHERE date_key >= now() - INTERVAL 90 DAY  -- Данные за последние 3 месяца
  GROUP BY 
    date_key, region, city, country, timezone, time_period, season
),

-- Расчет региональных метрик
enriched_regional AS (
  SELECT 
    *,
    -- Плотность устройств
    active_devices / GREATEST(active_locations, 1) as devices_per_location,
    
    -- Эффективность региона
    CASE 
      WHEN regional_avg_power_factor >= 0.9 THEN 'excellent'
      WHEN regional_avg_power_factor >= 0.8 THEN 'good'
      WHEN regional_avg_power_factor >= 0.7 THEN 'fair'
      ELSE 'poor'
    END as regional_efficiency_rating,
    
    -- Уровень потребления региона
    CASE 
      WHEN regional_total_consumption < 10000 THEN 'low'
      WHEN regional_total_consumption < 100000 THEN 'medium'
      WHEN regional_total_consumption < 1000000 THEN 'high'
      ELSE 'very_high'
    END as regional_consumption_level,
    
    -- Волатильность региона
    CASE 
      WHEN regional_consumption_stddev < 500 THEN 'low'
      WHEN regional_consumption_stddev < 5000 THEN 'medium'
      ELSE 'high'
    END as regional_volatility,
    
    -- Среднее потребление на устройство
    regional_total_consumption / GREATEST(active_devices, 1) as avg_consumption_per_device,
    
    -- Среднее потребление на локацию
    regional_total_consumption / GREATEST(active_locations, 1) as avg_consumption_per_location,
    
    -- Процент активных измерений
    CASE 
      WHEN total_measurements >= active_devices * 20 THEN 'high_activity'
      WHEN total_measurements >= active_devices * 10 THEN 'medium_activity'
      ELSE 'low_activity'
    END as regional_activity_level
  FROM regional_aggregation
),

-- Финальная обработка с бизнес-логикой
final_regional AS (
  SELECT 
    *,
    -- Бизнес-правила для регионов
    CASE 
      WHEN active_devices > 0 AND active_locations > 0 THEN 1 
      ELSE 0 
    END as device_location_validity,
    
    CASE 
      WHEN regional_total_consumption >= 0 THEN 1 
      ELSE 0 
    END as consumption_validity,
    
    CASE 
      WHEN total_measurements > 0 THEN 1 
      ELSE 0 
    END as measurement_validity,
    
    CASE 
      WHEN regional_avg_voltage >= 0 AND regional_avg_voltage <= 1000 THEN 1 
      ELSE 0 
    END as voltage_validity,
    
    -- Финальный DQ score для региона
    (device_location_validity + consumption_validity + measurement_validity + 
     voltage_validity + CASE WHEN regional_dq_score >= 0.8 THEN 1 ELSE 0 END) / 5.0 as final_regional_dq_score
  FROM enriched_regional
)

SELECT 
  date_key,
  region,
  city,
  country,
  timezone,
  time_period,
  season,
  active_devices,
  active_locations,
  total_measurements,
  regional_total_consumption,
  regional_avg_consumption,
  regional_peak_consumption,
  regional_min_consumption,
  regional_avg_voltage,
  regional_avg_current,
  regional_avg_power_factor,
  regional_avg_apparent_power,
  regional_avg_real_power,
  regional_avg_reactive_power,
  regional_avg_normalized_consumption,
  regional_consumption_stddev,
  regional_consumption_95th_percentile,
  regional_efficiency_rating,
  regional_consumption_level,
  regional_volatility,
  regional_activity_level,
  devices_per_location,
  avg_consumption_per_device,
  avg_consumption_per_location,
  regional_day_start,
  regional_day_end,
  final_regional_dq_score,
  now() as dbt_updated_at
FROM final_regional
WHERE final_regional_dq_score >= 0.8  -- Строгий фильтр по качеству для регионального анализа

{% if is_incremental() %}
  -- Инкрементальная загрузка
  AND date_key >= (SELECT max(date_key) FROM {{ this }})
{% endif %}
