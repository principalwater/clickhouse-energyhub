{{
  config(
    materialized='view',
    tags=['dds', 'market_data', 'view']
  )
}}

-- View для доступа к очищенным данным market_data
SELECT 
  timestamp,
  volume_mwh,
  trading_zone,
  price_eur_mwh,
  inserted_at,
  source
FROM {{ ref('dds_market_data_clean') }}
ORDER BY timestamp DESC, trading_zone
