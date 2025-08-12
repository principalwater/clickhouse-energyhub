{{
  config(
    materialized='table',
    schema='ods'
  )
}}

-- ODS слой: предочищенные данные о локациях
-- Базовые DQ проверки и очистка данных
WITH cleaned_data AS (
  SELECT 
    location_id,
    location_name,
    region,
    city,
    address,
    latitude,
    longitude,
    timezone,
    country,
    raw_data,
    inserted_at,
    source
  FROM {{ ref('raw_locations') }}
  WHERE 
    -- Базовые DQ проверки
    location_id IS NOT NULL 
    AND location_name IS NOT NULL 
    AND region IS NOT NULL
    AND city IS NOT NULL
    AND latitude IS NOT NULL
    AND longitude IS NOT NULL
    AND timezone IS NOT NULL
    AND country IS NOT NULL
    AND latitude BETWEEN -90 AND 90  -- Валидные координаты
    AND longitude BETWEEN -180 AND 180
)

SELECT 
  location_id,
  location_name,
  region,
  city,
  address,
  latitude,
  longitude,
  timezone,
  country,
  raw_data,
  inserted_at,
  source,
  -- Добавляем вычисляемые поля
  CASE 
    WHEN country = 'Russia' THEN 'domestic'
    ELSE 'international'
  END as location_type,
  CASE 
    WHEN region IN ('North', 'South', 'East', 'West', 'Central') THEN 'main_region'
    ELSE 'other_region'
  END as region_category,
  -- Вычисляем часовой пояс в UTC
  CASE 
    WHEN timezone = 'Europe/Moscow' THEN 3
    WHEN timezone = 'Europe/Kaliningrad' THEN 2
    WHEN timezone = 'Asia/Vladivostok' THEN 10
    ELSE 0
  END as timezone_offset_hours
FROM cleaned_data
