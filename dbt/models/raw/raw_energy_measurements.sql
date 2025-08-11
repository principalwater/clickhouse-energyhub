{{
  config(
    materialized='view',
    schema='raw',
    tags=['raw', 'kafka_data', 'energy_measurements']
  )
}}

-- RAW модель для энергетических измерений
-- Данные из Kafka в исходном виде без изменений

SELECT 
  -- Исходные поля из Kafka
  id,
  timestamp,
  energy_consumption,
  voltage,
  current,
  power_factor,
  device_id,
  location_id,
  
  -- Метаданные Kafka
  _kafka_topic,
  _kafka_partition,
  _kafka_offset,
  _kafka_timestamp,
  
  -- Системные поля
  created_at,
  updated_at,
  
  -- DQ метрики (базовые)
  CASE 
    WHEN id IS NOT NULL THEN 1 
    ELSE 0 
  END as id_completeness,
  
  CASE 
    WHEN timestamp IS NOT NULL THEN 1 
    ELSE 0 
  END as timestamp_completeness,
  
  CASE 
    WHEN energy_consumption IS NOT NULL THEN 1 
    ELSE 0 
  END as energy_consumption_completeness,
  
  -- Базовый DQ score для RAW слоя
  ROUND(
    (CASE WHEN id IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN timestamp IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN energy_consumption IS NOT NULL THEN 1 ELSE 0 END) / 3.0, 2
  ) as raw_dq_score

FROM {{ source('kafka', 'energy_measurements') }}

-- Фильтр по базовому качеству (только записи с ID и timestamp)
WHERE id IS NOT NULL 
  AND timestamp IS NOT NULL
