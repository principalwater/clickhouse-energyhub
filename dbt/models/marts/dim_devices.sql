{{
  config(
    materialized='table',
    schema='marts',
    engine='MergeTree()',
    order_by='device_id',
    tags=['marts', 'dimension', 'devices']
  )
}}

-- Измерение устройств для marts слоя
-- Эта модель создает готовую для анализа таблицу устройств

WITH staging_devices AS (
  SELECT 
    device_id,
    device_name,
    device_type_id,
    location_id,
    installation_date,
    power_rating_max,
    voltage_standard,
    manufacturer,
    model,
    serial_number,
    status,
    last_maintenance_date,
    next_maintenance_date,
    dq_score,
    created_at,
    updated_at
  FROM {{ ref('stg_devices') }}
  WHERE dq_score >= 0.8  -- Только данные с высоким качеством
),

device_types AS (
  SELECT 
    device_type_id,
    device_type_name,
    description,
    power_rating_min,
    power_rating_max as type_power_rating_max,
    voltage_standard as type_voltage_standard
  FROM {{ ref('device_types') }}
),

-- Дополнительные расчеты для устройств
enriched_devices AS (
  SELECT 
    d.*,
    dt.device_type_name,
    dt.description as device_type_description,
    dt.type_power_rating_max,
    dt.type_voltage_standard,
    
    -- Возраст устройства в днях
    DATEDIFF('day', d.installation_date, today()) as device_age_days,
    
    -- Возраст устройства в месяцах
    DATEDIFF('month', d.installation_date, today()) as device_age_months,
    
    -- Возраст устройства в годах
    DATEDIFF('year', d.installation_date, today()) as device_age_years,
    
    -- Дней с последнего обслуживания
    CASE 
      WHEN d.last_maintenance_date IS NOT NULL 
      THEN DATEDIFF('day', d.last_maintenance_date, today())
      ELSE NULL 
    END as days_since_last_maintenance,
    
    -- Дней до следующего обслуживания
    CASE 
      WHEN d.next_maintenance_date IS NOT NULL 
      THEN DATEDIFF('day', today(), d.next_maintenance_date)
      ELSE NULL 
    END as days_until_next_maintenance,
    
    -- Статус обслуживания
    CASE 
      WHEN d.last_maintenance_date IS NULL THEN 'Never Maintained'
      WHEN d.next_maintenance_date IS NULL THEN 'Maintenance Overdue'
      WHEN d.days_until_next_maintenance < 0 THEN 'Maintenance Overdue'
      WHEN d.days_until_next_maintenance <= 30 THEN 'Maintenance Due Soon'
      WHEN d.days_until_next_maintenance <= 90 THEN 'Maintenance Due'
      ELSE 'Maintenance OK'
    END as maintenance_status,
    
    -- Классификация мощности
    CASE 
      WHEN d.power_rating_max < 1000 THEN 'Low Power'
      WHEN d.power_rating_max < 5000 THEN 'Medium Power'
      WHEN d.power_rating_max < 20000 THEN 'High Power'
      ELSE 'Very High Power'
    END as power_classification,
    
    -- Соответствие типу устройства
    CASE 
      WHEN d.power_rating_max BETWEEN dt.power_rating_min AND dt.type_power_rating_max 
           AND d.voltage_standard = dt.type_voltage_standard 
      THEN 'Compliant'
      ELSE 'Non-Compliant'
    END as type_compliance,
    
    -- Эффективность использования мощности
    CASE 
      WHEN d.power_rating_max > 0 
      THEN ROUND(d.power_rating_max / dt.type_power_rating_max * 100, 2)
      ELSE NULL 
    END as power_utilization_pct
    
  FROM staging_devices d
  LEFT JOIN device_types dt ON d.device_type_id = dt.device_type_id
),

-- Агрегация по типам устройств
device_type_summary AS (
  SELECT 
    device_type_id,
    device_type_name,
    COUNT(*) as total_devices,
    AVG(power_rating_max) as avg_power_rating,
    MIN(power_rating_max) as min_power_rating,
    MAX(power_rating_max) as max_power_rating,
    AVG(device_age_days) as avg_device_age_days,
    COUNT(CASE WHEN maintenance_status = 'Maintenance Overdue' THEN 1 END) as overdue_maintenance_count,
    COUNT(CASE WHEN maintenance_status = 'Maintenance Due Soon' THEN 1 END) as due_soon_maintenance_count,
    AVG(dq_score) as avg_dq_score
  FROM enriched_devices
  GROUP BY device_type_id, device_type_name
)

-- Основной результат - обогащенные данные об устройствах
SELECT 
  d.device_id,
  d.device_name,
  d.device_type_id,
  d.device_type_name,
  d.device_type_description,
  d.location_id,
  d.installation_date,
  d.power_rating_max,
  d.voltage_standard,
  d.manufacturer,
  d.model,
  d.serial_number,
  d.status,
  d.last_maintenance_date,
  d.next_maintenance_date,
  
  -- Возрастные метрики
  d.device_age_days,
  d.device_age_months,
  d.device_age_years,
  
  -- Метрики обслуживания
  d.days_since_last_maintenance,
  d.days_until_next_maintenance,
  d.maintenance_status,
  
  -- Классификации
  d.power_classification,
  d.type_compliance,
  d.power_utilization_pct,
  
  -- DQ метрики
  d.dq_score,
  
  -- Агрегированные метрики по типу
  s.total_devices as devices_of_same_type,
  s.avg_power_rating as avg_power_rating_by_type,
  s.avg_device_age_days as avg_device_age_by_type,
  s.overdue_maintenance_count as overdue_maintenance_by_type,
  s.due_soon_maintenance_count as due_soon_maintenance_by_type,
  s.avg_dq_score as avg_dq_score_by_type,
  
  -- Системные поля
  d.created_at,
  d.updated_at,
  '{{ invocation_id }}' as dbt_run_id

FROM enriched_devices d
LEFT JOIN device_type_summary s ON d.device_type_id = s.device_type_id

ORDER BY d.device_id
