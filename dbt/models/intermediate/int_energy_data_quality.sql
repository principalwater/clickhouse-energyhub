{{
  config(
    materialized='view',
    schema='intermediate',
    tags=['intermediate', 'dq_analysis', 'energy_data']
  )
}}

-- Intermediate модель для анализа качества энергетических данных
-- Эта модель анализирует качество данных и создает метрики для мониторинга

WITH staging_data AS (
  SELECT 
    *,
    toDate(timestamp) as date_only,
    toHour(timestamp) as hour_only,
    toDayOfWeek(timestamp) as day_of_week
  FROM {{ ref('stg_energy_data') }}
),

-- Анализ полноты данных по дням
daily_completeness AS (
  SELECT 
    date_only,
    COUNT(*) as total_measurements,
    COUNT(CASE WHEN energy_consumption IS NOT NULL THEN 1 END) as energy_consumption_complete,
    COUNT(CASE WHEN voltage IS NOT NULL THEN 1 END) as voltage_complete,
    COUNT(CASE WHEN current IS NOT NULL THEN 1 END) as current_complete,
    COUNT(CASE WHEN power_factor IS NOT NULL THEN 1 END) as power_factor_complete,
    COUNT(CASE WHEN device_id IS NOT NULL THEN 1 END) as device_id_complete,
    COUNT(CASE WHEN location_id IS NOT NULL THEN 1 END) as location_id_complete,
    
    -- Процент полноты для каждого поля
    ROUND(COUNT(CASE WHEN energy_consumption IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2) as energy_consumption_completeness_pct,
    ROUND(COUNT(CASE WHEN voltage IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2) as voltage_completeness_pct,
    ROUND(COUNT(CASE WHEN current IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2) as current_completeness_pct,
    ROUND(COUNT(CASE WHEN power_factor IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2) as power_factor_completeness_pct,
    ROUND(COUNT(CASE WHEN device_id IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2) as device_id_completeness_pct,
    ROUND(COUNT(CASE WHEN location_id IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2) as location_id_completeness_pct
  FROM staging_data
  GROUP BY date_only
),

-- Анализ диапазонов значений
value_range_analysis AS (
  SELECT 
    date_only,
    COUNT(*) as total_measurements,
    
    -- Анализ энергопотребления
    COUNT(CASE WHEN energy_consumption >= 0 AND energy_consumption <= 10000 THEN 1 END) as energy_consumption_in_range,
    COUNT(CASE WHEN energy_consumption < 0 OR energy_consumption > 10000 THEN 1 END) as energy_consumption_out_of_range,
    
    -- Анализ напряжения
    COUNT(CASE WHEN voltage >= 200 AND voltage <= 250 THEN 1 END) as voltage_in_range,
    COUNT(CASE WHEN voltage < 200 OR voltage > 250 THEN 1 END) as voltage_out_of_range,
    
    -- Анализ тока
    COUNT(CASE WHEN current >= 0 AND current <= 100 THEN 1 END) as current_in_range,
    COUNT(CASE WHEN current < 0 OR current > 100 THEN 1 END) as current_out_of_range,
    
    -- Анализ коэффициента мощности
    COUNT(CASE WHEN power_factor >= 0.8 AND power_factor <= 1.0 THEN 1 END) as power_factor_in_range,
    COUNT(CASE WHEN power_factor < 0.8 OR power_factor > 1.0 THEN 1 END) as power_factor_out_of_range,
    
    -- Процент значений в диапазоне
    ROUND(COUNT(CASE WHEN energy_consumption >= 0 AND energy_consumption <= 10000 THEN 1 END) * 100.0 / COUNT(*), 2) as energy_consumption_range_pct,
    ROUND(COUNT(CASE WHEN voltage >= 200 AND voltage <= 250 THEN 1 END) * 100.0 / COUNT(*), 2) as voltage_range_pct,
    ROUND(COUNT(CASE WHEN current >= 0 AND current <= 100 THEN 1 END) * 100.0 / COUNT(*), 2) as current_range_pct,
    ROUND(COUNT(CASE WHEN power_factor >= 0.8 AND power_factor <= 1.0 THEN 1 END) * 100.0 / COUNT(*), 2) as power_factor_range_pct
  FROM staging_data
  GROUP BY date_only
),

-- Анализ уникальности
uniqueness_analysis AS (
  SELECT 
    date_only,
    COUNT(*) as total_measurements,
    COUNT(DISTINCT id) as unique_ids,
    COUNT(DISTINCT device_id) as unique_devices,
    COUNT(DISTINCT location_id) as unique_locations,
    
    -- Процент уникальности
    ROUND(COUNT(DISTINCT id) * 100.0 / COUNT(*), 2) as id_uniqueness_pct,
    ROUND(COUNT(DISTINCT device_id) * 100.0 / COUNT(*), 2) as device_uniqueness_pct,
    ROUND(COUNT(DISTINCT location_id) * 100.0 / COUNT(*), 2) as location_uniqueness_pct
  FROM staging_data
  GROUP BY date_only
),

-- Анализ DQ score
dq_score_analysis AS (
  SELECT 
    date_only,
    COUNT(*) as total_measurements,
    AVG(dq_score) as avg_dq_score,
    MIN(dq_score) as min_dq_score,
    MAX(dq_score) as max_dq_score,
    STDDEV(dq_score) as stddev_dq_score,
    
    -- Распределение по качеству
    COUNT(CASE WHEN dq_score >= 0.9 THEN 1 END) as high_quality_count,
    COUNT(CASE WHEN dq_score >= 0.8 AND dq_score < 0.9 THEN 1 END) as medium_quality_count,
    COUNT(CASE WHEN dq_score < 0.8 THEN 1 END) as low_quality_count,
    
    -- Процент высокого качества
    ROUND(COUNT(CASE WHEN dq_score >= 0.8 THEN 1 END) * 100.0 / COUNT(*), 2) as acceptable_quality_pct
  FROM staging_data
  GROUP BY date_only
)

-- Основной результат - объединенный анализ качества данных
SELECT 
  d.date_only,
  
  -- Общие метрики
  d.total_measurements,
  
  -- Метрики полноты
  d.energy_consumption_completeness_pct,
  d.voltage_completeness_pct,
  d.current_completeness_pct,
  d.power_factor_completeness_pct,
  d.device_id_completeness_pct,
  d.location_id_completeness_pct,
  
  -- Метрики диапазонов
  v.energy_consumption_range_pct,
  v.voltage_range_pct,
  v.current_range_pct,
  v.power_factor_range_pct,
  
  -- Метрики уникальности
  u.id_uniqueness_pct,
  u.device_uniqueness_pct,
  u.location_uniqueness_pct,
  
  -- Метрики DQ score
  q.avg_dq_score,
  q.min_dq_score,
  q.max_dq_score,
  q.stddev_dq_score,
  q.acceptable_quality_pct,
  
  -- Общий показатель качества (взвешенный)
  ROUND(
    (d.energy_consumption_completeness_pct + 
     v.energy_consumption_range_pct + 
     u.id_uniqueness_pct + 
     q.acceptable_quality_pct) / 4.0, 2
  ) as overall_quality_score,
  
  -- Классификация качества
  CASE 
    WHEN q.acceptable_quality_pct >= 95 THEN 'Excellent'
    WHEN q.acceptable_quality_pct >= 90 THEN 'Good'
    WHEN q.acceptable_quality_pct >= 80 THEN 'Acceptable'
    WHEN q.acceptable_quality_pct >= 70 THEN 'Needs Improvement'
    ELSE 'Poor'
  END as quality_rating,
  
  -- Временные метрики
  toDayOfWeek(d.date_only) as day_of_week,
  toMonth(d.date_only) as month,
  toYear(d.date_only) as year,
  
  -- Системные поля
  now() as created_at,
  now() as updated_at

FROM daily_completeness d
JOIN value_range_analysis v ON d.date_only = v.date_only
JOIN uniqueness_analysis u ON d.date_only = u.date_only
JOIN dq_score_analysis q ON d.date_only = q.date_only

ORDER BY d.date_only DESC
