{{
  config(
    materialized='table',
    schema='dds',
    engine='MergeTree()',
    order_by='device_id',
    tags=['dds', 'detailed', 'business_logic', 'devices']
  )
}}

-- DDS модель для справочника устройств
-- Детализированные данные об устройствах с бизнес-логикой

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
    END as power_utilization_pct,
    
    -- Критичность устройства
    CASE 
      WHEN d.power_rating_max >= 20000 THEN 'Critical'
      WHEN d.power_rating_max >= 10000 THEN 'High'
      WHEN d.power_rating_max >= 5000 THEN 'Medium'
      WHEN d.power_rating_max >= 1000 THEN 'Low'
      ELSE 'Very Low'
    END as device_criticality,
    
    -- Статус жизненного цикла
    CASE 
      WHEN d.device_age_years < 1 THEN 'New'
      WHEN d.device_age_years < 3 THEN 'Young'
      WHEN d.device_age_years < 7 THEN 'Mature'
      WHEN d.device_age_years < 15 THEN 'Aging'
      ELSE 'End of Life'
    END as lifecycle_status
    
  FROM staging_devices d
  LEFT JOIN device_types dt ON d.device_type_id = dt.device_type_id
)

-- Основной результат - детализированные данные об устройствах
SELECT 
  device_id,
  device_name,
  device_type_id,
  device_type_name,
  device_type_description,
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
  
  -- Возрастные метрики
  device_age_days,
  device_age_months,
  device_age_years,
  
  -- Метрики обслуживания
  days_since_last_maintenance,
  days_until_next_maintenance,
  maintenance_status,
  
  -- Классификации
  power_classification,
  type_compliance,
  power_utilization_pct,
  device_criticality,
  lifecycle_status,
  
  -- DQ метрики
  dq_score,
  
  -- Системные поля
  created_at,
  updated_at,
  '{{ invocation_id }}' as dbt_run_id

FROM enriched_devices

ORDER BY device_id
