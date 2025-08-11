{{
  config(
    materialized='view',
    schema='ods',
    tags=['ods', 'staging', 'energy_measurements', 'dq_checked']
  )
}}

-- Staging модель для измерений энергии в ODS слое
-- Предобработка данных об энергопотреблении с DQ проверками

WITH source_data AS (
  SELECT 
    id,
    timestamp,
    energy_consumption,
    voltage,
    current,
    power_factor,
    device_id,
    location_id,
    created_at,
    updated_at
  FROM {{ ref('raw_energy_measurements') }}
  WHERE timestamp >= now() - INTERVAL 7 DAY  -- Данные за последнюю неделю
),

-- DQ проверки с использованием макросов
dq_checked_data AS (
  SELECT 
    *,
    -- Проверка полноты критических полей
    CASE 
      WHEN id IS NOT NULL THEN 1 
      ELSE 0 
    END as id_completeness,
    
    CASE 
      WHEN timestamp IS NOT NULL THEN 1 
      ELSE 0 
    END as timestamp_completeness,
    
    CASE 
      WHEN device_id IS NOT NULL THEN 1 
      ELSE 0 
    END as device_id_completeness,
    
    CASE 
      WHEN location_id IS NOT NULL THEN 1 
      ELSE 0 
    END as location_id_completeness,
    
    -- Проверка диапазона значений
    CASE 
      WHEN energy_consumption >= 0 AND energy_consumption <= 1000000 THEN 1 
      ELSE 0 
    END as energy_consumption_range_check,
    
    CASE 
      WHEN voltage >= 0 AND voltage <= 1000 THEN 1 
      ELSE 0 
    END as voltage_range_check,
    
    CASE 
      WHEN current >= 0 AND current <= 10000 THEN 1 
      ELSE 0 
    END as current_range_check,
    
    CASE 
      WHEN power_factor >= 0 AND power_factor <= 1 THEN 1 
      ELSE 0 
    END as power_factor_range_check
    
  FROM source_data
),

-- Валидация бизнес-правил
business_rules_validated AS (
  SELECT 
    *,
    -- Проверка согласованности измерений
    CASE 
      WHEN voltage > 0 AND current > 0 THEN 1 
      WHEN voltage = 0 AND current = 0 THEN 1
      ELSE 0 
    END as voltage_current_consistency,
    
    -- Проверка временной последовательности
    CASE 
      WHEN timestamp <= now() THEN 1 
      ELSE 0 
    END as timestamp_validity,
    
    -- Проверка логики энергопотребления
    CASE 
      WHEN energy_consumption >= voltage * current * power_factor * 0.001 THEN 1 
      ELSE 0 
    END as energy_calculation_check
    
  FROM dq_checked_data
)

SELECT 
  id,
  timestamp,
  energy_consumption,
  voltage,
  current,
  power_factor,
  device_id,
  location_id,
  
  -- DQ метрики
  id_completeness,
  timestamp_completeness,
  device_id_completeness,
  location_id_completeness,
  energy_consumption_range_check,
  voltage_range_check,
  current_range_check,
  power_factor_range_check,
  voltage_current_consistency,
  timestamp_validity,
  energy_calculation_check,
  
  -- Общий DQ score для ODS слоя (взвешенный)
  ROUND(
    (id_completeness * 0.15 +                -- Критическое поле
     timestamp_completeness * 0.15 +          -- Критическое поле
     device_id_completeness * 0.15 +          -- Критическое поле
     location_id_completeness * 0.15 +        -- Критическое поле
     energy_consumption_range_check * 0.1 +   -- Бизнес-правило
     voltage_range_check * 0.05 +             -- Бизнес-правило
     current_range_check * 0.05 +             -- Бизнес-правило
     power_factor_range_check * 0.05 +        -- Бизнес-правило
     voltage_current_consistency * 0.03 +     -- Бизнес-правило
     timestamp_validity * 0.01 +              -- Валидация
     energy_calculation_check * 0.01), 2     -- Бизнес-правило
  ) as dq_score,
  
  -- Системные поля
  created_at,
  updated_at

FROM business_rules_validated

-- Фильтр по качеству данных для ODS слоя
WHERE dq_score >= 0.8

ORDER BY timestamp DESC, id
