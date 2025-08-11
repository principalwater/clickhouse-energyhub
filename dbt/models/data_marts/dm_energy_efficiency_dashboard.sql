{{
  config(
    materialized='table',
    schema='data_marts',
    engine='MergeTree()',
    order_by='date_only',
    partition_by='toYYYYMM(date_only)',
    tags=['data_marts', 'aggregated', 'bi_ready', 'efficiency_dashboard']
  )
}}

-- Data Mart для дашборда энергоэффективности
-- Готовые для BI агрегированные данные по эффективности

WITH dds_data AS (
  SELECT 
    *,
    toDate(timestamp) as date_only,
    toStartOfDay(timestamp) as day_timestamp,
    toStartOfMonth(timestamp) as month_timestamp
  FROM {{ ref('dds_energy_consumption') }}
  WHERE anomaly_flag = 'Normal'  -- Исключаем аномальные данные
),

-- Дневная агрегация по эффективности
daily_efficiency_metrics AS (
  SELECT 
    date_only,
    day_timestamp,
    month_timestamp,
    
    -- Общие метрики
    COUNT(*) as total_measurements,
    COUNT(DISTINCT device_id) as unique_devices,
    COUNT(DISTINCT location_id) as unique_locations,
    
    -- Энергетические метрики
    ROUND(SUM(energy_consumption), 3) as total_energy_consumption,
    ROUND(AVG(energy_consumption), 3) as avg_energy_consumption,
    ROUND(SUM(real_power_kw), 3) as total_real_power_kw,
    ROUND(AVG(real_power_kw), 3) as avg_real_power_kw,
    
    -- Эффективность по рейтингам
    COUNT(CASE WHEN efficiency_rating = 'High Efficiency' THEN 1 END) as high_efficiency_count,
    COUNT(CASE WHEN efficiency_rating = 'Good Efficiency' THEN 1 END) as good_efficiency_count,
    COUNT(CASE WHEN efficiency_rating = 'Acceptable Efficiency' THEN 1 END) as acceptable_efficiency_count,
    COUNT(CASE WHEN efficiency_rating = 'Low Efficiency' THEN 1 END) as low_efficiency_count,
    
    -- Процент эффективности
    ROUND(COUNT(CASE WHEN efficiency_rating IN ('High Efficiency', 'Good Efficiency') THEN 1 END) * 100.0 / COUNT(*), 2) as high_good_efficiency_percent,
    ROUND(COUNT(CASE WHEN efficiency_rating = 'Low Efficiency' THEN 1 END) * 100.0 / COUNT(*), 2) as low_efficiency_percent,
    
    -- Нагрузка устройств
    ROUND(AVG(device_load_percent), 2) as avg_device_load_percent,
    ROUND(MAX(device_load_percent), 2) as max_device_load_percent,
    
    -- Стоимость
    ROUND(SUM(estimated_cost_rub_per_hour), 4) as total_cost_rub_per_day,
    ROUND(AVG(estimated_cost_rub_per_hour), 4) as avg_cost_rub_per_hour,
    
    -- DQ метрики
    ROUND(AVG(ods_dq_score), 3) as avg_dq_score,
    
    -- Временные метрики
    toDayOfWeek(day_timestamp) as day_of_week,
    toMonth(day_timestamp) as month,
    toYear(day_timestamp) as year,
    
    -- Системные поля
    now() as created_at,
    now() as updated_at,
    '{{ invocation_id }}' as dbt_run_id
    
  FROM dds_data
  GROUP BY date_only, day_timestamp, month_timestamp
),

-- Месячная агрегация по эффективности
monthly_efficiency_metrics AS (
  SELECT 
    month_timestamp,
    toDate(month_timestamp) as month_date,
    
    -- Общие метрики
    COUNT(*) as total_measurements,
    COUNT(DISTINCT device_id) as unique_devices,
    COUNT(DISTINCT location_id) as unique_locations,
    
    -- Энергетические метрики
    ROUND(SUM(energy_consumption), 3) as month_total_energy_consumption,
    ROUND(AVG(energy_consumption), 3) as month_avg_energy_consumption,
    ROUND(SUM(real_power_kw), 3) as month_total_real_power_kw,
    ROUND(AVG(real_power_kw), 3) as month_avg_real_power_kw,
    
    -- Эффективность по рейтингам
    COUNT(CASE WHEN efficiency_rating = 'High Efficiency' THEN 1 END) as month_high_efficiency_count,
    COUNT(CASE WHEN efficiency_rating = 'Good Efficiency' THEN 1 END) as month_good_efficiency_count,
    COUNT(CASE WHEN efficiency_rating = 'Acceptable Efficiency' THEN 1 END) as month_acceptable_efficiency_count,
    COUNT(CASE WHEN efficiency_rating = 'Low Efficiency' THEN 1 END) as month_low_efficiency_count,
    
    -- Процент эффективности
    ROUND(COUNT(CASE WHEN efficiency_rating IN ('High Efficiency', 'Good Efficiency') THEN 1 END) * 100.0 / COUNT(*), 2) as month_high_good_efficiency_percent,
    ROUND(COUNT(CASE WHEN efficiency_rating = 'Low Efficiency' THEN 1 END) * 100.0 / COUNT(*), 2) as month_low_efficiency_percent,
    
    -- Нагрузка устройств
    ROUND(AVG(device_load_percent), 2) as month_avg_device_load_percent,
    ROUND(MAX(device_load_percent), 2) as month_max_device_load_percent,
    
    -- Стоимость
    ROUND(SUM(estimated_cost_rub_per_hour), 4) as month_total_cost_rub,
    ROUND(AVG(estimated_cost_rub_per_hour), 4) as month_avg_cost_rub_per_hour,
    
    -- DQ метрики
    ROUND(AVG(ods_dq_score), 3) as month_avg_dq_score,
    
    -- Временные метрики
    toMonth(month_timestamp) as month_number,
    toYear(month_timestamp) as year,
    
    -- Системные поля
    now() as created_at,
    now() as updated_at,
    '{{ invocation_id }}' as dbt_run_id
    
  FROM dds_data
  GROUP BY month_timestamp
),

-- Агрегация по типам устройств
device_type_efficiency_metrics AS (
  SELECT 
    date_only,
    device_type_id,
    
    -- Общие метрики
    COUNT(*) as total_measurements,
    COUNT(DISTINCT device_id) as unique_devices,
    
    -- Энергетические метрики
    ROUND(SUM(energy_consumption), 3) as device_type_total_energy_consumption,
    ROUND(AVG(energy_consumption), 3) as device_type_avg_energy_consumption,
    ROUND(SUM(real_power_kw), 3) as device_type_total_real_power_kw,
    ROUND(AVG(real_power_kw), 3) as device_type_avg_real_power_kw,
    
    -- Эффективность по рейтингам
    COUNT(CASE WHEN efficiency_rating = 'High Efficiency' THEN 1 END) as device_type_high_efficiency_count,
    COUNT(CASE WHEN efficiency_rating = 'Good Efficiency' THEN 1 END) as device_type_good_efficiency_count,
    COUNT(CASE WHEN efficiency_rating = 'Acceptable Efficiency' THEN 1 END) as device_type_acceptable_efficiency_count,
    COUNT(CASE WHEN efficiency_rating = 'Low Efficiency' THEN 1 END) as device_type_low_efficiency_count,
    
    -- Процент эффективности
    ROUND(COUNT(CASE WHEN efficiency_rating IN ('High Efficiency', 'Good Efficiency') THEN 1 END) * 100.0 / COUNT(*), 2) as device_type_high_good_efficiency_percent,
    ROUND(COUNT(CASE WHEN efficiency_rating = 'Low Efficiency' THEN 1 END) * 100.0 / COUNT(*), 2) as device_type_low_efficiency_percent,
    
    -- Нагрузка устройств
    ROUND(AVG(device_load_percent), 2) as device_type_avg_device_load_percent,
    ROUND(MAX(device_load_percent), 2) as device_type_max_device_load_percent,
    
    -- Стоимость
    ROUND(SUM(estimated_cost_rub_per_hour), 4) as device_type_total_cost_rub_per_day,
    ROUND(AVG(estimated_cost_rub_per_hour), 4) as device_type_avg_cost_rub_per_hour,
    
    -- DQ метрики
    ROUND(AVG(ods_dq_score), 3) as device_type_avg_dq_score,
    
    -- Системные поля
    now() as created_at,
    now() as updated_at,
    '{{ invocation_id }}' as dbt_run_id
    
  FROM dds_data
  GROUP BY date_only, device_type_id
)

-- Основной результат - агрегированные метрики эффективности для BI
SELECT 
  'daily_efficiency' as metric_type,
  date_only,
  day_timestamp,
  month_timestamp,
  NULL as device_type_id,
  
  -- Общие метрики
  total_measurements,
  unique_devices,
  unique_locations,
  
  -- Энергетические метрики
  total_energy_consumption,
  avg_energy_consumption,
  total_real_power_kw,
  avg_real_power_kw,
  
  -- Эффективность
  high_efficiency_count,
  good_efficiency_count,
  acceptable_efficiency_count,
  low_efficiency_count,
  high_good_efficiency_percent,
  low_efficiency_percent,
  
  -- Нагрузка
  avg_device_load_percent,
  max_device_load_percent,
  
  -- Стоимость
  total_cost_rub_per_day,
  avg_cost_rub_per_hour,
  
  -- DQ метрики
  avg_dq_score,
  
  -- Временные метрики
  day_of_week,
  month,
  year,
  
  -- Системные поля
  created_at,
  updated_at,
  dbt_run_id

FROM daily_efficiency_metrics

UNION ALL

SELECT 
  'monthly_efficiency' as metric_type,
  month_date as date_only,
  month_timestamp as day_timestamp,
  month_timestamp,
  NULL as device_type_id,
  
  -- Общие метрики
  total_measurements,
  unique_devices,
  unique_locations,
  
  -- Энергетические метрики
  month_total_energy_consumption as total_energy_consumption,
  month_avg_energy_consumption as avg_energy_consumption,
  month_total_real_power_kw as total_real_power_kw,
  month_avg_real_power_kw as avg_real_power_kw,
  
  -- Эффективность
  month_high_efficiency_count as high_efficiency_count,
  month_good_efficiency_count as good_efficiency_count,
  month_acceptable_efficiency_count as acceptable_efficiency_count,
  month_low_efficiency_count as low_efficiency_count,
  month_high_good_efficiency_percent as high_good_efficiency_percent,
  month_low_efficiency_percent as low_efficiency_percent,
  
  -- Нагрузка
  month_avg_device_load_percent as avg_device_load_percent,
  month_max_device_load_percent as max_device_load_percent,
  
  -- Стоимость
  month_total_cost_rub as total_cost_rub_per_day,
  month_avg_cost_rub_per_hour as avg_cost_rub_per_hour,
  
  -- DQ метрики
  month_avg_dq_score as avg_dq_score,
  
  -- Временные метрики
  NULL as day_of_week,
  month_number as month,
  year,
  
  -- Системные поля
  created_at,
  updated_at,
  dbt_run_id

FROM monthly_efficiency_metrics

UNION ALL

SELECT 
  'device_type_efficiency' as metric_type,
  date_only,
  NULL as day_timestamp,
  NULL as month_timestamp,
  device_type_id,
  
  -- Общие метрики
  total_measurements,
  unique_devices,
  NULL as unique_locations,
  
  -- Энергетические метрики
  device_type_total_energy_consumption as total_energy_consumption,
  device_type_avg_energy_consumption as avg_energy_consumption,
  device_type_total_real_power_kw as total_real_power_kw,
  device_type_avg_real_power_kw as avg_real_power_kw,
  
  -- Эффективность
  device_type_high_efficiency_count as high_efficiency_count,
  device_type_good_efficiency_count as good_efficiency_count,
  device_type_acceptable_efficiency_count as acceptable_efficiency_count,
  device_type_low_efficiency_count as low_efficiency_count,
  device_type_high_good_efficiency_percent as high_good_efficiency_percent,
  device_type_low_efficiency_percent as low_efficiency_percent,
  
  -- Нагрузка
  device_type_avg_device_load_percent as avg_device_load_percent,
  device_type_max_device_load_percent as max_device_load_percent,
  
  -- Стоимость
  device_type_total_cost_rub_per_day as total_cost_rub_per_day,
  device_type_avg_cost_rub_per_hour as avg_cost_rub_per_hour,
  
  -- DQ метрики
  device_type_avg_dq_score as avg_dq_score,
  
  -- Временные метрики
  NULL as day_of_week,
  NULL as month,
  NULL as year,
  
  -- Системные поля
  created_at,
  updated_at,
  dbt_run_id

FROM device_type_efficiency_metrics

ORDER BY metric_type, date_only DESC, device_type_id
