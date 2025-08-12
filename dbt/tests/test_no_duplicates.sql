-- Тест для проверки отсутствия дублей в dds_river_flow_clean
SELECT 
    ges_name,
    timestamp,
    river_name,
    COUNT(*) as duplicate_count
FROM {{ ref('dds_river_flow_clean') }}
GROUP BY ges_name, timestamp, river_name
HAVING COUNT(*) > 1

UNION ALL

-- Тест для проверки отсутствия дублей в dds_market_data_clean
SELECT 
    'market_data' as ges_name,
    timestamp,
    trading_zone as river_name,
    COUNT(*) as duplicate_count
FROM {{ ref('dds_market_data_clean') }}
GROUP BY timestamp, trading_zone
HAVING COUNT(*) > 1
