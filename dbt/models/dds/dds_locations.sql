{{
  config(
    materialized='table',
    schema='dds',
    tags=['dds', 'dimension', 'locations', 'cluster_optimized'],
    indexes=[
      {'columns': ['location_id'], 'type': 'minmax'},
      {'columns': ['region', 'city'], 'type': 'set'},
      {'columns': ['country'], 'type': 'set'}
    ]
  )
}}

-- Dimension таблица для локаций в DDS слое
-- Детализированные данные о локациях с бизнес-логикой

WITH staging_locations AS (
  SELECT 
    location_id,
    location_name,
    region,
    city,
    timezone,
    latitude,
    longitude,
    address,
    postal_code,
    country,
    is_active,
    created_at,
    updated_at
  FROM {{ ref('stg_locations') }}
  WHERE dq_score >= 0.8  -- Только качественные данные
),

-- Обогащение данными о временных зонах
enriched_locations AS (
  SELECT 
    *,
    -- Определение часового пояса по координатам
    CASE 
      WHEN latitude BETWEEN 55.0 AND 60.0 AND longitude BETWEEN 30.0 AND 40.0 THEN 'Europe/Moscow'
      WHEN latitude BETWEEN 50.0 AND 60.0 AND longitude BETWEEN 40.0 AND 60.0 THEN 'Asia/Yekaterinburg'
      WHEN latitude BETWEEN 50.0 AND 60.0 AND longitude BETWEEN 60.0 AND 80.0 THEN 'Asia/Novosibirsk'
      WHEN latitude BETWEEN 40.0 AND 50.0 AND longitude BETWEEN 120.0 AND 140.0 THEN 'Asia/Vladivostok'
      WHEN latitude BETWEEN 54.0 AND 56.0 AND longitude BETWEEN 20.0 AND 23.0 THEN 'Europe/Kaliningrad'
      ELSE timezone
    END as calculated_timezone,
    
    -- Определение региона по координатам
    CASE 
      WHEN latitude BETWEEN 55.0 AND 60.0 AND longitude BETWEEN 30.0 AND 40.0 THEN 'Центральный'
      WHEN latitude BETWEEN 50.0 AND 60.0 AND longitude BETWEEN 40.0 AND 60.0 THEN 'Уральский'
      WHEN latitude BETWEEN 50.0 AND 60.0 AND longitude BETWEEN 60.0 AND 80.0 THEN 'Сибирский'
      WHEN latitude BETWEEN 40.0 AND 50.0 AND longitude BETWEEN 120.0 AND 140.0 THEN 'Дальневосточный'
      WHEN latitude BETWEEN 54.0 AND 56.0 AND longitude BETWEEN 20.0 AND 23.0 THEN 'Северо-Западный'
      ELSE region
    END as calculated_region,
    
    -- Определение типа локации
    CASE 
      WHEN city IS NOT NULL AND city != '' THEN 'Город'
      WHEN region IS NOT NULL AND region != '' THEN 'Регион'
      ELSE 'Другое'
    END as location_type,
    
    -- Статус активности с бизнес-логикой
    CASE 
      WHEN is_active = 1 AND updated_at >= now() - INTERVAL 1 YEAR THEN 'Активная'
      WHEN is_active = 1 AND updated_at < now() - INTERVAL 1 YEAR THEN 'Требует обновления'
      ELSE 'Неактивная'
    END as business_status
    
  FROM staging_locations
)

SELECT 
  location_id,
  location_name,
  COALESCE(calculated_region, region) as region,
  city,
  COALESCE(calculated_timezone, timezone) as timezone,
  latitude,
  longitude,
  address,
  postal_code,
  country,
  location_type,
  business_status,
  is_active,
  
  -- Дополнительные поля для аналитики
  CASE 
    WHEN latitude IS NOT NULL AND longitude IS NOT NULL THEN 1 
    ELSE 0 
  END as has_coordinates,
  
  CASE 
    WHEN address IS NOT NULL AND address != '' THEN 1 
    ELSE 0 
  END as has_address,
  
  -- Системные поля
  created_at,
  updated_at,
  now() as dbt_updated_at

FROM enriched_locations

ORDER BY location_id
