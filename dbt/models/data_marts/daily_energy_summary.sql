{{
  config(
    materialized='table',
    schema='data_marts',
    tags=['data_marts', 'daily_summary', 'energy_analytics'],
    indexes=[
      {'columns': ['date_key'], 'type': 'minmax'},
      {'columns': ['region'], 'type': 'set'},
      {'columns': ['device_type'], 'type': 'set'}
    ]
  )
}}

-- Data Mart для ежедневной сводки по энергопотреблению
-- Агрегированные данные для BI и аналитики

WITH daily_aggregation AS (
  SELECT 
    date_key,
    region,
    city,
    country,
    device_type,
    time_period,
    season,
    
    -- Агрегированные метрики по дням
    COUNT(DISTINCT device_id) as active_devices,
    COUNT(DISTINCT location_id) as active_locations,
    SUM(measurement_count) as total_measurements,
    
    -- Энергопотребление
    ROUND(SUM(total_consumption), 4) as daily_total_consumption,
    ROUND(AVG(avg_consumption), 4) as daily_avg_consumption,
    ROUND(MAX(max_consumption), 4) as daily_peak_consumption,
    ROUND(MIN(min_consumption), 4) as daily_min_consumption,
    
    -- Электрические параметры
    ROUND(AVG(avg_voltage), 2) as daily_avg_voltage,
    ROUND(AVG(avg_current), 2) as daily_avg_current,
    ROUND(AVG(avg_power_factor), 4) as daily_avg_power_factor,
    
    -- Мощность
    ROUND(AVG(avg_real_power), 2) as daily_avg_real_power,
    ROUND(AVG(avg_apparent_power), 2) as daily_avg_apparent_power,
    ROUND(AVG(avg_reactive_power), 4) as daily_avg_reactive_power,
    
    -- Статистика
    ROUND(AVG(consumption_stddev), 4) as daily_consumption_stddev,
    ROUND(AVG(consumption_95th_percentile), 4) as daily_consumption_95th_percentile,
    
    -- Временные метрики
    MIN(first_measurement_time) as day_start_time,
    MAX(last_measurement_time) as day_end_time,
    
    -- Системные поля
    now() as dbt_updated_at
    
  FROM {{ ref('fact_energy_consumption') }}
  
  GROUP BY 
    date_key, region, city, country, device_type, time_period, season
),

-- Расчет дополнительных метрик
enriched_summary AS (
  SELECT 
    *,
    
    -- Эффективность энергопотребления
    CASE 
      WHEN daily_avg_power_factor > 0.9 THEN 'Высокая'
      WHEN daily_avg_power_factor > 0.8 THEN 'Средняя'
      ELSE 'Низкая'
    END as power_efficiency_rating,
    
    -- Классификация по потреблению
    CASE 
      WHEN daily_total_consumption > 10000 THEN 'Высокое'
      WHEN daily_total_consumption > 1000 THEN 'Среднее'
      ELSE 'Низкое'
    END as consumption_level,
    
    -- Аномалии в данных
    CASE 
      WHEN daily_consumption_stddev > daily_avg_consumption * 2 THEN 'Высокая'
      WHEN daily_consumption_stddev > daily_avg_consumption THEN 'Средняя'
      ELSE 'Низкая'
    END as data_volatility,
    
    -- Расчет коэффициента использования
    ROUND(
      daily_total_consumption / (active_devices * 24), 4
    ) as avg_consumption_per_device_hour
    
  FROM daily_aggregation
)

SELECT 
  -- Ключи
  date_key,
  region,
  city,
  country,
  device_type,
  time_period,
  season,
  
  -- Метрики активности
  active_devices,
  active_locations,
  total_measurements,
  
  -- Энергопотребление
  daily_total_consumption,
  daily_avg_consumption,
  daily_peak_consumption,
  daily_min_consumption,
  
  -- Электрические параметры
  daily_avg_voltage,
  daily_avg_current,
  daily_avg_power_factor,
  
  -- Мощность
  daily_avg_real_power,
  daily_avg_apparent_power,
  daily_avg_reactive_power,
  
  -- Статистика
  daily_consumption_stddev,
  daily_consumption_95th_percentile,
  
  -- Дополнительные метрики
  power_efficiency_rating,
  consumption_level,
  data_volatility,
  avg_consumption_per_device_hour,
  
  -- Временные метрики
  day_start_time,
  day_end_time,
  
  -- Системные поля
  dbt_updated_at

FROM enriched_summary

ORDER BY date_key DESC, region, city, device_type
