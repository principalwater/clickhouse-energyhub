{{
  config(
    materialized='view',
    schema='staging',
    tags=['staging', 'devices', 'dimension']
  )
}}

-- Staging модель для справочника устройств
-- Эта модель подготавливает данные об устройствах для дальнейшего анализа

WITH source_data AS (
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
    created_at,
    updated_at
  FROM {{ source('raw', 'devices') }}
  WHERE status = 'active'  -- Только активные устройства
),

-- DQ проверки с использованием макросов
dq_checked_data AS (
  SELECT 
    *,
    -- Проверка полноты критических полей
    CASE 
      WHEN device_id IS NOT NULL THEN 1 
      ELSE 0 
    END as device_id_completeness,
    
    CASE 
      WHEN device_name IS NOT NULL THEN 1 
      ELSE 0 
    END as device_name_completeness,
    
    CASE 
      WHEN device_type_id IS NOT NULL THEN 1 
      ELSE 0 
    END as device_type_id_completeness,
    
    CASE 
      WHEN location_id IS NOT NULL THEN 1 
      ELSE 0 
    END as location_id_completeness,
    
    -- Проверка диапазона значений
    CASE 
      WHEN power_rating_max >= 0 AND power_rating_max <= 100000 THEN 1 
      ELSE 0 
    END as power_rating_range_check,
    
    CASE 
      WHEN voltage_standard IN (220, 380) THEN 1 
      ELSE 0 
    END as voltage_standard_check,
    
    -- Проверка формата даты
    CASE 
      WHEN toDate(installation_date) IS NOT NULL THEN 1 
      ELSE 0 
    END as installation_date_format_check,
    
    CASE 
      WHEN toDate(last_maintenance_date) IS NOT NULL OR last_maintenance_date IS NULL THEN 1 
      ELSE 0 
    END as last_maintenance_date_format_check,
    
    CASE 
      WHEN toDate(next_maintenance_date) IS NOT NULL OR next_maintenance_date IS NULL THEN 1 
      ELSE 0 
    END as next_maintenance_date_format_check
    
  FROM source_data
),

-- Валидация бизнес-правил
business_rules_validated AS (
  SELECT 
    *,
    -- Проверка согласованности дат
    CASE 
      WHEN installation_date IS NOT NULL AND last_maintenance_date IS NOT NULL 
           AND installation_date <= last_maintenance_date THEN 1 
      WHEN installation_date IS NOT NULL AND last_maintenance_date IS NULL THEN 1
      ELSE 0 
    END as date_consistency_check,
    
    -- Проверка согласованности дат обслуживания
    CASE 
      WHEN last_maintenance_date IS NOT NULL AND next_maintenance_date IS NOT NULL 
           AND last_maintenance_date <= next_maintenance_date THEN 1 
      WHEN last_maintenance_date IS NULL AND next_maintenance_date IS NULL THEN 1
      WHEN last_maintenance_date IS NOT NULL AND next_maintenance_date IS NULL THEN 1
      ELSE 0 
    END as maintenance_date_consistency_check,
    
    -- Проверка статуса устройства
    CASE 
      WHEN status IN ('active', 'inactive', 'maintenance', 'retired') THEN 1 
      ELSE 0 
    END as status_validity_check
    
  FROM dq_checked_data
)

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
  
  -- DQ метрики
  device_id_completeness,
  device_name_completeness,
  device_type_id_completeness,
  location_id_completeness,
  power_rating_range_check,
  voltage_standard_check,
  installation_date_format_check,
  last_maintenance_date_format_check,
  next_maintenance_date_format_check,
  date_consistency_check,
  maintenance_date_consistency_check,
  status_validity_check,
  
  -- Общий DQ score (взвешенный по важности полей)
  ROUND(
    (device_id_completeness * 0.2 +           -- Критическое поле
     device_name_completeness * 0.15 +        -- Важное поле
     device_type_id_completeness * 0.15 +     -- Важное поле
     location_id_completeness * 0.15 +        -- Важное поле
     power_rating_range_check * 0.1 +         -- Бизнес-правило
     voltage_standard_check * 0.1 +           -- Бизнес-правило
     installation_date_format_check * 0.05 +  -- Формат
     date_consistency_check * 0.05 +          -- Бизнес-правило
     status_validity_check * 0.05), 2         -- Валидация
  ) as dq_score,
  
  -- Системные поля
  created_at,
  updated_at

FROM business_rules_validated

-- Фильтр по качеству данных
WHERE dq_score >= 0.8

ORDER BY device_id
