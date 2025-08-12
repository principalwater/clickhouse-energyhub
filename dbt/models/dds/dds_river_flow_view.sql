{{
  config(
    materialized='view',
    tags=['dds', 'river_flow', 'view']
  )
}}

-- View для доступа к очищенным данным river_flow
SELECT 
  ges_name,
  timestamp,
  river_name,
  water_level_m,
  flow_rate_m3_s,
  power_output_mw,
  inserted_at,
  source
FROM {{ ref('dds_river_flow_clean') }}
ORDER BY timestamp DESC, ges_name, river_name
