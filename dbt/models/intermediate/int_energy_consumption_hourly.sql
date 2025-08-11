{{
  config(
    materialized='incremental',
    schema='intermediate',
    tags=['intermediate', 'energy_consumption', 'hourly_aggregation'],
    unique_key=['date_key', 'hour_key', 'device_id', 'location_id'],
    incremental_strategy='merge'
  )
}}

-- Промежуточная модель для почасового потребления энергии
-- Агрегация данных из ODS слоя для DDS

WITH hourly_measurements AS (
  SELECT 
    toDate(timestamp) as date_key,
    toHour(timestamp) as hour_key,
    device_id,
    location_id,
    -- Агрегация измерений по часам
    count() as measurement_count,
    avg(energy_consumption) as avg_consumption,
    sum(energy_consumption) as total_consumption,
    max(energy_consumption) as max_consumption,
    min(energy_consumption) as min_consumption,
    avg(voltage) as avg_voltage,
    avg(current) as avg_current,
    avg(power_factor) as avg_power_factor,
    -- Расчет мощности
    avg(voltage * current * 0.001) as avg_apparent_power,
    avg(voltage * current * power_factor * 0.001) as avg_real_power,
    avg(voltage * current * sqrt(1 - power_factor * power_factor) * 0.001) as avg_reactive_power,
    -- Статистика
    stddevSamp(energy_consumption) as consumption_stddev,
    quantile(0.95)(energy_consumption) as consumption_95th_percentile,
    -- Временные метки
    min(timestamp) as first_measurement_time,
    max(timestamp) as last_measurement_time
  FROM {{ ref('stg_energy_measurements') }}
  WHERE timestamp >= now() - INTERVAL 30 DAY  -- Данные за последний месяц
  GROUP BY date_key, hour_key, device_id, location_id
),

-- Обогащение данными об устройствах и локациях
enriched_data AS (
  SELECT 
    hm.*,
    d.device_type,
    d.device_name,
    d.device_status,
    l.region,
    l.city,
    l.country,
    l.timezone,
    -- Временные характеристики
    CASE 
      WHEN hm.hour_key >= 6 AND hm.hour_key <= 22 THEN 'day'
      ELSE 'night'
    END as time_period,
    -- Сезонность
    CASE 
      WHEN hm.date_key BETWEEN '2024-12-01' AND '2024-02-28' THEN 'winter'
      WHEN hm.date_key BETWEEN '2024-03-01' AND '2024-05-31' THEN 'spring'
      WHEN hm.date_key BETWEEN '2024-06-01' AND '2024-08-31' THEN 'summer'
      WHEN hm.date_key BETWEEN '2024-09-01' AND '2024-11-30' THEN 'autumn'
    END as season,
    -- Нормализованное потребление (кВтч)
    hm.total_consumption / 1000 as normalized_consumption,
    -- Эффективность
    CASE 
      WHEN hm.avg_power_factor >= 0.9 THEN 'high'
      WHEN hm.avg_power_factor >= 0.7 THEN 'medium'
      ELSE 'low'
    END as power_efficiency_rating
  FROM hourly_measurements hm
  LEFT JOIN {{ ref('stg_devices') }} d ON hm.device_id = d.id
  LEFT JOIN {{ ref('stg_locations') }} l ON hm.location_id = l.id
),

-- Финальная обработка с DQ проверками
final_data AS (
  SELECT 
    *,
    -- DQ проверки
    CASE 
      WHEN measurement_count > 0 THEN 1 
      ELSE 0 
    END as measurement_count_valid,
    
    CASE 
      WHEN avg_consumption >= 0 AND avg_consumption <= 1000000 THEN 1 
      ELSE 0 
    END as consumption_range_valid,
    
    CASE 
      WHEN avg_voltage >= 0 AND avg_voltage <= 1000 THEN 1 
      ELSE 0 
    END as voltage_range_valid,
    
    CASE 
      WHEN avg_current >= 0 AND avg_current <= 10000 THEN 1 
      ELSE 0 
    END as current_range_valid,
    
    -- Расчет DQ score
    (measurement_count_valid + consumption_range_valid + voltage_range_valid + current_range_valid) / 4.0 as dq_score
  FROM enriched_data
)

SELECT 
  date_key,
  hour_key,
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
  measurement_count,
  avg_consumption,
  total_consumption,
  max_consumption,
  min_consumption,
  avg_voltage,
  avg_current,
  avg_power_factor,
  avg_apparent_power,
  avg_real_power,
  avg_reactive_power,
  normalized_consumption,
  consumption_stddev,
  consumption_95th_percentile,
  power_efficiency_rating,
  first_measurement_time,
  last_measurement_time,
  dq_score,
  now() as dbt_updated_at
FROM final_data
WHERE dq_score >= 0.75  -- Фильтр по качеству данных

{% if is_incremental() %}
  -- Инкрементальная загрузка
  AND date_key >= (SELECT max(date_key) FROM {{ this }})
{% endif %}
