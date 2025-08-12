{{
  config(
    materialized='table',
    tags=['dds', 'river_flow', 'clean']
  )
}}

WITH deduplicated_river_flow AS (
  SELECT 
    ges_name,
    timestamp,
    river_name,
    water_level_m,
    flow_rate_m3_s,
    power_output_mw,
    -- Используем ROW_NUMBER для удаления дублей, оставляя только первую запись
    ROW_NUMBER() OVER (
      PARTITION BY ges_name, timestamp, river_name 
      ORDER BY timestamp DESC
    ) as rn
  FROM {{ source('raw', 'river_flow') }}
  WHERE ges_name IS NOT NULL 
    AND timestamp IS NOT NULL 
    AND river_name IS NOT NULL
)

SELECT 
  ges_name,
  timestamp,
  river_name,
  water_level_m,
  flow_rate_m3_s,
  power_output_mw,
  -- Добавляем метаданные
  now() as inserted_at,
  'dbt_clean' as source
FROM deduplicated_river_flow
WHERE rn = 1
