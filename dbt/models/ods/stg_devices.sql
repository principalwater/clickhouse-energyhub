{{
  config(
    materialized='view',
    schema='ods',
    tags=['ods', 'staging', 'devices', 'dq_checked']
  )
}}

-- Staging модель для устройств в ODS слое
-- Предобработка данных об устройствах с DQ проверками

WITH source_data AS (
  SELECT 
    device_id,
    device_name,
    device_type,
    manufacturer,
    model,
    serial_number,
    installation_date,
    last_maintenance_date,
    status,
    location_id,
    technical_specs,
    metadata,
    created_at,
    updated_at
  FROM {{ ref('raw_devices') }}
  WHERE status IN ('active', 'maintenance', 'offline')  -- Валидные статусы
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
      WHEN device_name IS NOT NULL AND device_name != '' THEN 1 
      ELSE 0 
    END as device_name_completeness,
    
    CASE 
      WHEN device_type IS NOT NULL THEN 1 
      ELSE 0 
    END as device_type_completeness,
    
    CASE 
      WHEN location_id IS NOT NULL THEN 1 
      ELSE 0 
    END as location_id_completeness,
    
    -- Проверка формата данных
    CASE 
      WHEN serial_number IS NOT NULL AND length(serial_number) >= 5 THEN 1 
      ELSE 0 
    END as serial_number_format_check,
    
    -- Проверка дат
    CASE 
      WHEN installation_date IS NOT NULL AND installation_date <= today() THEN 1 
      ELSE 0 
    END as installation_date_check,
    
    CASE 
      WHEN last_maintenance_date IS NULL OR last_maintenance_date <= today() THEN 1 
      ELSE 0 
    END as maintenance_date_check
    
  FROM source_data
),

-- Валидация бизнес-правил
business_rules_validated AS (
  SELECT 
    *,
    -- Проверка согласованности статуса и дат
    CASE 
      WHEN status = 'maintenance' AND last_maintenance_date IS NOT NULL THEN 1 
      WHEN status != 'maintenance' THEN 1
      ELSE 0 
    END as status_maintenance_consistency,
    
    -- Проверка типа устройства
    CASE 
      WHEN device_type IN ('sensor', 'meter', 'controller', 'gateway') THEN 1 
      ELSE 0 
    END as device_type_validity,
    
    -- Проверка производителя
    CASE 
      WHEN manufacturer IS NOT NULL AND manufacturer != '' THEN 1 
      ELSE 0 
    END as manufacturer_validity
    
  FROM dq_checked_data
)

SELECT 
  device_id,
  device_name,
  device_type,
  manufacturer,
  model,
  serial_number,
  installation_date,
  last_maintenance_date,
  status,
  location_id,
  technical_specs,
  metadata,
  
  -- DQ метрики
  device_id_completeness,
  device_name_completeness,
  device_type_completeness,
  location_id_completeness,
  serial_number_format_check,
  installation_date_check,
  maintenance_date_check,
  status_maintenance_consistency,
  device_type_validity,
  manufacturer_validity,
  
  -- Общий DQ score для ODS слоя (взвешенный)
  ROUND(
    (device_id_completeness * 0.2 +           -- Критическое поле
     device_name_completeness * 0.15 +        -- Важное поле
     device_type_completeness * 0.15 +        -- Важное поле
     location_id_completeness * 0.15 +        -- Важное поле
     serial_number_format_check * 0.1 +       -- Формат
     installation_date_check * 0.1 +          -- Бизнес-правило
     maintenance_date_check * 0.05 +          -- Бизнес-правило
     status_maintenance_consistency * 0.05 +  -- Бизнес-правило
     device_type_validity * 0.03 +            -- Валидация
     manufacturer_validity * 0.02), 2         -- Валидация
  ) as dq_score,
  
  -- Системные поля
  created_at,
  updated_at

FROM business_rules_validated

-- Фильтр по качеству данных для ODS слоя
WHERE dq_score >= 0.7

ORDER BY device_id
