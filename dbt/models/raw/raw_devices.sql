{{
  config(
    materialized='view',
    schema='raw',
    tags=['raw', 'devices', 'kafka_data']
  )
}}

-- Сырые данные об устройствах из Kafka
-- Первичная обработка без DQ проверок

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
  _kafka_topic,
  _kafka_partition,
  _kafka_offset,
  _kafka_timestamp,
  created_at,
  updated_at
FROM {{ source('kafka', 'devices') }}

-- Базовая фильтрация по времени
WHERE _kafka_timestamp >= now() - INTERVAL 30 DAY
