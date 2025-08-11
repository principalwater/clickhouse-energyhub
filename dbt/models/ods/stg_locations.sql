{{
  config(
    materialized='view',
    schema='ods',
    tags=['ods', 'staging', 'locations']
  )
}}

-- Staging модель для локаций в ODS слое
-- Предобработка данных о локациях с DQ проверками

WITH source_data AS (
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
  FROM {{ source('reference', 'locations') }}
  WHERE is_active = 1  -- Только активные локации
),

-- DQ проверки с использованием макросов
dq_checked_data AS (
  SELECT 
    *,
    -- Проверка полноты критических полей
    CASE 
      WHEN location_id IS NOT NULL THEN 1 
      ELSE 0 
    END as location_id_completeness,
    
    CASE 
      WHEN location_name IS NOT NULL THEN 1 
      ELSE 0 
    END as location_name_completeness,
    
    CASE 
      WHEN region IS NOT NULL THEN 1 
      ELSE 0 
    END as region_completeness,
    
    CASE 
      WHEN city IS NOT NULL THEN 1 
      ELSE 0 
    END as city_completeness,
    
    CASE 
      WHEN country IS NOT NULL THEN 1 
      ELSE 0 
    END as country_completeness,
    
    -- Проверка диапазона значений
    CASE 
      WHEN latitude >= -90 AND latitude <= 90 THEN 1 
      ELSE 0 
    END as latitude_range_check,
    
    CASE 
      WHEN longitude >= -180 AND longitude <= 180 THEN 1 
      ELSE 0 
    END as longitude_range_check,
    
    -- Проверка формата данных
    CASE 
      WHEN timezone IS NOT NULL AND timezone != '' THEN 1 
      ELSE 0 
    END as timezone_format_check,
    
    CASE 
      WHEN postal_code IS NOT NULL AND postal_code != '' THEN 1 
      ELSE 0 
    END as postal_code_format_check
    
  FROM source_data
),

-- Валидация бизнес-правил
business_rules_validated AS (
  SELECT 
    *,
    -- Проверка согласованности координат
    CASE 
      WHEN latitude IS NOT NULL AND longitude IS NOT NULL THEN 1 
      WHEN latitude IS NULL AND longitude IS NULL THEN 1
      ELSE 0 
    END as coordinates_consistency_check,
    
    -- Проверка логики адреса
    CASE 
      WHEN address IS NOT NULL OR (city IS NOT NULL AND country IS NOT NULL) THEN 1 
      ELSE 0 
    END as address_logic_check,
    
    -- Проверка временной зоны
    CASE 
      WHEN timezone IN ('Europe/Moscow', 'Asia/Yekaterinburg', 'Asia/Novosibirsk', 'Asia/Vladivostok', 'Europe/Kaliningrad') THEN 1 
      ELSE 0 
    END as timezone_validity_check
    
  FROM dq_checked_data
)

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
  
  -- DQ метрики
  location_id_completeness,
  location_name_completeness,
  region_completeness,
  city_completeness,
  country_completeness,
  latitude_range_check,
  longitude_range_check,
  timezone_format_check,
  postal_code_format_check,
  coordinates_consistency_check,
  address_logic_check,
  timezone_validity_check,
  
  -- Общий DQ score для ODS слоя (взвешенный)
  ROUND(
    (location_id_completeness * 0.2 +         -- Критическое поле
     location_name_completeness * 0.15 +      -- Важное поле
     region_completeness * 0.1 +              -- Важное поле
     city_completeness * 0.15 +               -- Важное поле
     country_completeness * 0.1 +             -- Важное поле
     latitude_range_check * 0.05 +            -- Бизнес-правило
     longitude_range_check * 0.05 +           -- Бизнес-правило
     timezone_format_check * 0.05 +           -- Формат
     postal_code_format_check * 0.05 +        -- Формат
     coordinates_consistency_check * 0.05 +    -- Бизнес-правило
     address_logic_check * 0.05), 2           -- Бизнес-правило
  ) as dq_score,
  
  -- Системные поля
  created_at,
  updated_at

FROM business_rules_validated

-- Фильтр по качеству данных для ODS слоя
WHERE dq_score >= 0.7

ORDER BY location_id
