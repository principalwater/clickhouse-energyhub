{{
  config(
    materialized='view',
    schema='staging',
    tags=['staging', 'energy_data']
  )
}}

-- Staging модель для энергетических данных с DQ проверками
-- Эта модель подготавливает сырые данные для дальнейшего анализа

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
  FROM {{ source('raw', 'energy_measurements') }}
  WHERE timestamp >= '2024-01-01'  -- Фильтр по дате для производительности
),

-- DQ проверки с использованием макросов
dq_checked_data AS (
  SELECT 
    *,
    -- Проверка полноты критических полей
    CASE 
      WHEN energy_consumption IS NOT NULL THEN 1 
      ELSE 0 
    END as energy_consumption_completeness,
    
    -- Проверка диапазона значений
    CASE 
      WHEN energy_consumption >= 0 AND energy_consumption <= 10000 THEN 1 
      ELSE 0 
    END as energy_consumption_range_check,
    
    -- Проверка формата даты
    CASE 
      WHEN toDate(timestamp) IS NOT NULL THEN 1 
      ELSE 0 
    END as timestamp_format_check
    
  FROM source_data
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
  created_at,
  updated_at,
  
  -- DQ метрики
  energy_consumption_completeness,
  energy_consumption_range_check,
  timestamp_format_check,
  
  -- Общий DQ score
  (energy_consumption_completeness + energy_consumption_range_check + timestamp_format_check) / 3.0 as dq_score
  
FROM dq_checked_data

-- Фильтр по DQ score (только данные с высоким качеством)
WHERE dq_score >= 0.8
