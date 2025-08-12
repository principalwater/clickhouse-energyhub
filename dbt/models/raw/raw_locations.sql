{{
  config(
    materialized='table',
    schema='raw',
    tags=['raw']
  )
}}

-- Raw слой: сырые данные о локациях
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
  -- Добавляем метаданные
  now() as inserted_at,
  'raw_data' as source
FROM {{ source('raw', 'locations_raw') }}
