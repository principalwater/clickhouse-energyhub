{{
  config(
    materialized='table',
    schema='data_marts',
    engine='MergeTree()',
    order_by='hour_timestamp',
    partition_by='toYYYYMM(hour_timestamp)',
    tags=['data_marts', 'aggregated', 'bi_ready', 'hourly_aggregates']
  )
}}

-- Data Mart для почасовых агрегатов потребления энергии
-- Готовые для BI агрегированные данные

WITH dds_data AS (
  SELECT 
    *,
    toStartOfHour(timestamp) as hour_timestamp,
    toDate(timestamp) as date_only
  FROM {{ ref('dds_energy_consumption') }}
  WHERE anomaly_flag = 'Normal'  -- Исключаем аномальные данные
),

-- Почасовая агрегация по устройствам
hourly_device_aggregation AS (
  SELECT 
    hour_timestamp,
    date_only,
    device_id,
    device_name,
    device_type_id,
    location_id,
    location_name,
    region,
    city,
    
    -- Количество измерений
    COUNT(*) as measurement_count,
    
    -- Энергетические метрики
    ROUND(AVG(energy_consumption), 3) as avg_energy_consumption,
    ROUND(SUM(energy_consumption), 3) as total_energy_consumption,
    ROUND(MAX(energy_consumption), 3) as max_energy_consumption,
    ROUND(MIN(energy_consumption), 3) as min_energy_consumption,
    ROUND(STDDEV(energy_consumption), 3) as stddev_energy_consumption,
    
    -- Электрические параметры
    ROUND(AVG(voltage), 1) as avg_voltage,
    ROUND(AVG(current), 2) as avg_current,
    ROUND(AVG(power_factor), 3) as avg_power_factor,
    ROUND(AVG(real_power_kw), 3) as avg_real_power_kw,
    ROUND(SUM(real_power_kw), 3) as total_real_power_kw,
    
    -- Эффективность
    ROUND(AVG(CASE WHEN efficiency_rating = 'High Efficiency' THEN 1 ELSE 0 END) * 100, 2) as high_efficiency_percent,
    ROUND(AVG(CASE WHEN efficiency_rating = 'Good Efficiency' THEN 1 ELSE 0 END) * 100, 2) as good_efficiency_percent,
    ROUND(AVG(CASE WHEN efficiency_rating = 'Acceptable Efficiency' THEN 1 ELSE 0 END) * 100, 2) as acceptable_efficiency_percent,
    ROUND(AVG(CASE WHEN efficiency_rating = 'Low Efficiency' THEN 1 ELSE 0 END) * 100, 2) as low_efficiency_percent,
    
    -- Нагрузка
    ROUND(AVG(device_load_percent), 2) as avg_device_load_percent,
    ROUND(MAX(device_load_percent), 2) as max_device_load_percent,
    
    -- Стоимость
    ROUND(SUM(estimated_cost_rub_per_hour), 4) as total_cost_rub_per_hour,
    ROUND(AVG(estimated_cost_rub_per_hour), 4) as avg_cost_rub_per_hour,
    
    -- Временные метрики
    toHour(hour_timestamp) as hour_of_day,
    toDayOfWeek(hour_timestamp) as day_of_week,
    toMonth(hour_timestamp) as month,
    toYear(hour_timestamp) as year,
    
    -- DQ метрики
    ROUND(AVG(ods_dq_score), 3) as avg_dq_score,
    MIN(data_quality_rating) as min_data_quality_rating,
    
    -- Системные поля
    now() as created_at,
    now() as updated_at,
    '{{ invocation_id }}' as dbt_run_id
    
  FROM dds_data
  GROUP BY 
    hour_timestamp, date_only, device_id, device_name, device_type_id, 
    location_id, location_name, region, city
),

-- Почасовая агрегация по локациям
hourly_location_aggregation AS (
  SELECT 
    hour_timestamp,
    date_only,
    location_id,
    location_name,
    region,
    city,
    
    -- Количество устройств
    COUNT(DISTINCT device_id) as unique_devices,
    
    -- Энергетические метрики
    ROUND(SUM(total_energy_consumption), 3) as location_total_energy_consumption,
    ROUND(AVG(avg_energy_consumption), 3) as location_avg_energy_consumption,
    ROUND(MAX(max_energy_consumption), 3) as location_max_energy_consumption,
    
    -- Электрические параметры
    ROUND(AVG(avg_voltage), 1) as location_avg_voltage,
    ROUND(AVG(avg_current), 2) as location_avg_current,
    ROUND(AVG(avg_power_factor), 3) as location_avg_power_factor,
    
    -- Эффективность
    ROUND(AVG(high_efficiency_percent), 2) as location_high_efficiency_percent,
    ROUND(AVG(good_efficiency_percent), 2) as location_good_efficiency_percent,
    ROUND(AVG(acceptable_efficiency_percent), 2) as location_acceptable_efficiency_percent,
    ROUND(AVG(low_efficiency_percent), 2) as location_low_efficiency_percent,
    
    -- Нагрузка
    ROUND(AVG(avg_device_load_percent), 2) as location_avg_device_load_percent,
    ROUND(MAX(max_device_load_percent), 2) as location_max_device_load_percent,
    
    -- Стоимость
    ROUND(SUM(total_cost_rub_per_hour), 4) as location_total_cost_rub_per_hour,
    ROUND(AVG(avg_cost_rub_per_hour), 4) as location_avg_cost_rub_per_hour,
    
    -- DQ метрики
    ROUND(AVG(avg_dq_score), 3) as location_avg_dq_score,
    
    -- Системные поля
    now() as created_at,
    now() as updated_at,
    '{{ invocation_id }}' as dbt_run_id
    
  FROM hourly_device_aggregation
  GROUP BY hour_timestamp, date_only, location_id, location_name, region, city
),

-- Почасовая агрегация по типам устройств
hourly_device_type_aggregation AS (
  SELECT 
    hour_timestamp,
    date_only,
    device_type_id,
    
    -- Количество устройств
    COUNT(DISTINCT device_id) as unique_devices,
    
    -- Энергетические метрики
    ROUND(SUM(total_energy_consumption), 3) as device_type_total_energy_consumption,
    ROUND(AVG(avg_energy_consumption), 3) as device_type_avg_energy_consumption,
    ROUND(MAX(max_energy_consumption), 3) as device_type_max_energy_consumption,
    
    -- Электрические параметры
    ROUND(AVG(avg_voltage), 1) as device_type_avg_voltage,
    ROUND(AVG(avg_current), 2) as device_type_avg_current,
    ROUND(AVG(avg_power_factor), 3) as device_type_avg_power_factor,
    
    -- Эффективность
    ROUND(AVG(high_efficiency_percent), 2) as device_type_high_efficiency_percent,
    ROUND(AVG(good_efficiency_percent), 2) as device_type_good_efficiency_percent,
    ROUND(AVG(acceptable_efficiency_percent), 2) as device_type_acceptable_efficiency_percent,
    ROUND(AVG(low_efficiency_percent), 2) as device_type_low_efficiency_percent,
    
    -- Нагрузка
    ROUND(AVG(avg_device_load_percent), 2) as device_type_avg_device_load_percent,
    ROUND(MAX(max_device_load_percent), 2) as device_type_max_device_load_percent,
    
    -- Стоимость
    ROUND(SUM(total_cost_rub_per_hour), 4) as device_type_total_cost_rub_per_hour,
    ROUND(AVG(avg_cost_rub_per_hour), 4) as device_type_avg_cost_rub_per_hour,
    
    -- DQ метрики
    ROUND(AVG(avg_dq_score), 3) as device_type_avg_dq_score,
    
    -- Системные поля
    now() as created_at,
    now() as updated_at,
    '{{ invocation_id }}' as dbt_run_id
    
  FROM hourly_device_aggregation
  GROUP BY hour_timestamp, date_only, device_type_id
)

-- Основной результат - почасовые агрегаты для BI
SELECT 
  'device_level' as aggregation_level,
  hour_timestamp,
  date_only,
  device_id,
  device_name,
  device_type_id,
  location_id,
  location_name,
  region,
  city,
  
  -- Метрики
  measurement_count,
  avg_energy_consumption,
  total_energy_consumption,
  max_energy_consumption,
  min_energy_consumption,
  stddev_energy_consumption,
  avg_voltage,
  avg_current,
  avg_power_factor,
  avg_real_power_kw,
  total_real_power_kw,
  high_efficiency_percent,
  good_efficiency_percent,
  acceptable_efficiency_percent,
  low_efficiency_percent,
  avg_device_load_percent,
  max_device_load_percent,
  total_cost_rub_per_hour,
  avg_cost_rub_per_hour,
  
  -- Временные метрики
  hour_of_day,
  day_of_week,
  month,
  year,
  
  -- DQ метрики
  avg_dq_score,
  min_data_quality_rating,
  
  -- Системные поля
  created_at,
  updated_at,
  dbt_run_id

FROM hourly_device_aggregation

UNION ALL

SELECT 
  'location_level' as aggregation_level,
  hour_timestamp,
  date_only,
  NULL as device_id,
  NULL as device_name,
  NULL as device_type_id,
  location_id,
  location_name,
  region,
  city,
  
  -- Метрики
  unique_devices as measurement_count,
  location_avg_energy_consumption as avg_energy_consumption,
  location_total_energy_consumption as total_energy_consumption,
  location_max_energy_consumption as max_energy_consumption,
  NULL as min_energy_consumption,
  NULL as stddev_energy_consumption,
  location_avg_voltage as avg_voltage,
  location_avg_current as avg_current,
  location_avg_power_factor as avg_power_factor,
  NULL as avg_real_power_kw,
  NULL as total_real_power_kw,
  location_high_efficiency_percent as high_efficiency_percent,
  location_good_efficiency_percent as good_efficiency_percent,
  location_acceptable_efficiency_percent as acceptable_efficiency_percent,
  location_low_efficiency_percent as low_efficiency_percent,
  location_avg_device_load_percent as avg_device_load_percent,
  location_max_device_load_percent as max_device_load_percent,
  location_total_cost_rub_per_hour as total_cost_rub_per_hour,
  location_avg_cost_rub_per_hour as avg_cost_rub_per_hour,
  
  -- Временные метрики
  toHour(hour_timestamp) as hour_of_day,
  toDayOfWeek(hour_timestamp) as day_of_week,
  toMonth(hour_timestamp) as month,
  toYear(hour_timestamp) as year,
  
  -- DQ метрики
  location_avg_dq_score as avg_dq_score,
  NULL as min_data_quality_rating,
  
  -- Системные поля
  created_at,
  updated_at,
  dbt_run_id

FROM hourly_location_aggregation

UNION ALL

SELECT 
  'device_type_level' as aggregation_level,
  hour_timestamp,
  date_only,
  NULL as device_id,
  NULL as device_name,
  device_type_id,
  NULL as location_id,
  NULL as location_name,
  NULL as region,
  NULL as city,
  
  -- Метрики
  unique_devices as measurement_count,
  device_type_avg_energy_consumption as avg_energy_consumption,
  device_type_total_energy_consumption as total_energy_consumption,
  device_type_max_energy_consumption as max_energy_consumption,
  NULL as min_energy_consumption,
  NULL as stddev_energy_consumption,
  device_type_avg_voltage as avg_voltage,
  device_type_avg_current as avg_current,
  device_type_avg_power_factor as avg_power_factor,
  NULL as avg_real_power_kw,
  NULL as total_real_power_kw,
  device_type_high_efficiency_percent as high_efficiency_percent,
  device_type_good_efficiency_percent as good_efficiency_percent,
  device_type_acceptable_efficiency_percent as acceptable_efficiency_percent,
  device_type_low_efficiency_percent as low_efficiency_percent,
  device_type_avg_device_load_percent as avg_device_load_percent,
  device_type_max_device_load_percent as max_device_load_percent,
  device_type_total_cost_rub_per_hour as total_cost_rub_per_hour,
  device_type_avg_cost_rub_per_hour as avg_cost_rub_per_hour,
  
  -- Временные метрики
  toHour(hour_timestamp) as hour_of_day,
  toDayOfWeek(hour_timestamp) as day_of_week,
  toMonth(hour_timestamp) as month,
  toYear(hour_timestamp) as year,
  
  -- DQ метрики
  device_type_avg_dq_score as avg_dq_score,
  NULL as min_data_quality_rating,
  
  -- Системные поля
  created_at,
  updated_at,
  dbt_run_id

FROM hourly_device_type_aggregation

ORDER BY aggregation_level, hour_timestamp DESC, device_id, location_id, device_type_id
