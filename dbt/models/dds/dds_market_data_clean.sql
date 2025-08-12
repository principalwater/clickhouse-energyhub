{{
  config(
    materialized='table',
    tags=['dds', 'market_data', 'clean']
  )
}}

WITH deduplicated_market_data AS (
  SELECT 
    timestamp,
    volume_mwh,
    trading_zone,
    price_eur_mwh,
    -- Используем ROW_NUMBER для удаления дублей, оставляя только первую запись
    ROW_NUMBER() OVER (
      PARTITION BY timestamp, trading_zone 
      ORDER BY timestamp DESC
    ) as rn
  FROM {{ source('ods', 'market_data') }}
  WHERE timestamp IS NOT NULL 
    AND trading_zone IS NOT NULL
)

SELECT 
  timestamp,
  volume_mwh,
  trading_zone,
  price_eur_mwh,
  -- Добавляем метаданные
  now() as inserted_at,
  'dbt_clean' as source
FROM deduplicated_market_data
WHERE rn = 1
