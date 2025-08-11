-- Примеры SQL запросов для анализа данных
-- ClickHouse EnergyHub

-- 1. Анализ энергопотребления по регионам
SELECT 
    region,
    city,
    COUNT(DISTINCT device_id) as device_count,
    ROUND(SUM(daily_total_consumption), 2) as total_consumption,
    ROUND(AVG(daily_avg_consumption), 4) as avg_consumption,
    ROUND(MAX(daily_peak_consumption), 4) as peak_consumption,
    power_efficiency_rating
FROM daily_energy_summary
WHERE date_key >= today() - INTERVAL 30 DAY
GROUP BY region, city, power_efficiency_rating
ORDER BY total_consumption DESC;

-- 2. Анализ эффективности по типам устройств
SELECT 
    device_type,
    COUNT(DISTINCT device_id) as device_count,
    ROUND(AVG(daily_avg_power_factor), 4) as avg_power_factor,
    ROUND(AVG(daily_avg_real_power), 2) as avg_real_power,
    ROUND(AVG(daily_avg_apparent_power), 2) as avg_apparent_power,
    CASE 
        WHEN AVG(daily_avg_power_factor) > 0.9 THEN 'Отличная'
        WHEN AVG(daily_avg_power_factor) > 0.8 THEN 'Хорошая'
        WHEN AVG(daily_avg_power_factor) > 0.7 THEN 'Удовлетворительная'
        ELSE 'Требует улучшения'
    END as efficiency_status
FROM daily_energy_summary
WHERE date_key >= today() - INTERVAL 7 DAY
GROUP BY device_type
ORDER BY avg_power_factor DESC;

-- 3. Анализ сезонности энергопотребления
SELECT 
    season,
    time_period,
    COUNT(DISTINCT date_key) as days_count,
    ROUND(AVG(daily_total_consumption), 2) as avg_daily_consumption,
    ROUND(SUM(daily_total_consumption), 2) as total_season_consumption,
    ROUND(AVG(daily_avg_voltage), 2) as avg_voltage,
    ROUND(AVG(daily_avg_current), 2) as avg_current
FROM daily_energy_summary
WHERE date_key >= today() - INTERVAL 365 DAY
GROUP BY season, time_period
ORDER BY season, time_period;

-- 4. Анализ аномалий в данных
SELECT 
    date_key,
    region,
    city,
    device_type,
    daily_total_consumption,
    daily_consumption_stddev,
    data_volatility,
    CASE 
        WHEN daily_consumption_stddev > daily_avg_consumption * 2 THEN 'Критическая'
        WHEN daily_consumption_stddev > daily_avg_consumption THEN 'Высокая'
        ELSE 'Нормальная'
    END as anomaly_level
FROM daily_energy_summary
WHERE daily_consumption_stddev > daily_avg_consumption
    AND date_key >= today() - INTERVAL 7 DAY
ORDER BY anomaly_level DESC, daily_consumption_stddev DESC;

-- 5. Анализ производительности устройств
SELECT 
    d.device_id,
    d.device_name,
    d.device_type,
    d.manufacturer,
    l.region,
    l.city,
    COUNT(*) as measurement_count,
    ROUND(AVG(e.energy_consumption), 4) as avg_consumption,
    ROUND(AVG(e.voltage), 2) as avg_voltage,
    ROUND(AVG(e.current), 2) as avg_current,
    ROUND(AVG(e.power_factor), 4) as avg_power_factor,
    ROUND(MAX(e.timestamp) - MIN(e.timestamp), 2) as uptime_hours
FROM fact_energy_consumption f
JOIN stg_devices d ON f.device_id = d.device_id
JOIN stg_locations l ON f.location_id = l.location_id
JOIN stg_energy_measurements e ON f.device_id = e.device_id
WHERE f.date_key >= today() - INTERVAL 7 DAY
GROUP BY d.device_id, d.device_name, d.device_type, d.manufacturer, l.region, l.city
HAVING measurement_count > 100
ORDER BY avg_power_factor DESC;

-- 6. Анализ географического распределения
SELECT 
    country,
    region,
    COUNT(DISTINCT l.location_id) as location_count,
    COUNT(DISTINCT d.device_id) as device_count,
    ROUND(SUM(f.total_consumption), 2) as total_consumption,
    ROUND(AVG(f.avg_consumption), 4) as avg_consumption,
    ROUND(AVG(f.avg_voltage), 2) as avg_voltage,
    ROUND(AVG(f.avg_power_factor), 4) as avg_power_factor
FROM fact_energy_consumption f
JOIN stg_locations l ON f.location_id = l.location_id
JOIN stg_devices d ON f.device_id = d.device_id
WHERE f.date_key >= today() - INTERVAL 30 DAY
GROUP BY country, region
ORDER BY total_consumption DESC;

-- 7. Анализ трендов энергопотребления
WITH daily_trends AS (
    SELECT 
        date_key,
        ROUND(SUM(total_consumption), 2) as daily_total,
        ROUND(AVG(avg_consumption), 4) as daily_avg,
        ROUND(AVG(avg_power_factor), 4) as daily_pf,
        COUNT(DISTINCT device_id) as active_devices
    FROM fact_energy_consumption
    WHERE date_key >= today() - INTERVAL 90 DAY
    GROUP BY date_key
)
SELECT 
    date_key,
    daily_total,
    daily_avg,
    daily_pf,
    active_devices,
    ROUND(
        (daily_total - LAG(daily_total) OVER (ORDER BY date_key)) / 
        LAG(daily_total) OVER (ORDER BY date_key) * 100, 2
    ) as consumption_change_percent,
    ROUND(
        (daily_pf - LAG(daily_pf) OVER (ORDER BY date_key)) / 
        LAG(daily_pf) OVER (ORDER BY date_key) * 100, 2
    ) as power_factor_change_percent
FROM daily_trends
ORDER BY date_key;

-- 8. Анализ качества данных (DQ)
SELECT 
    'stg_locations' as model_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN dq_score >= 0.9 THEN 1 END) as excellent_quality,
    COUNT(CASE WHEN dq_score >= 0.8 AND dq_score < 0.9 THEN 1 END) as good_quality,
    COUNT(CASE WHEN dq_score >= 0.7 AND dq_score < 0.8 THEN 1 END) as acceptable_quality,
    COUNT(CASE WHEN dq_score < 0.7 THEN 1 END) as poor_quality,
    ROUND(AVG(dq_score), 4) as avg_dq_score
FROM stg_locations
UNION ALL
SELECT 
    'stg_devices' as model_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN dq_score >= 0.9 THEN 1 END) as excellent_quality,
    COUNT(CASE WHEN dq_score >= 0.8 AND dq_score < 0.9 THEN 1 END) as good_quality,
    COUNT(CASE WHEN dq_score >= 0.7 AND dq_score < 0.8 THEN 1 END) as acceptable_quality,
    COUNT(CASE WHEN dq_score < 0.7 THEN 1 END) as poor_quality,
    ROUND(AVG(dq_score), 4) as avg_dq_score
FROM stg_devices
UNION ALL
SELECT 
    'stg_energy_measurements' as model_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN dq_score >= 0.9 THEN 1 END) as excellent_quality,
    COUNT(CASE WHEN dq_score >= 0.8 AND dq_score < 0.9 THEN 1 END) as good_quality,
    COUNT(CASE WHEN dq_score >= 0.7 AND dq_score < 0.8 THEN 1 END) as acceptable_quality,
    COUNT(CASE WHEN dq_score < 0.7 THEN 1 END) as poor_quality,
    ROUND(AVG(dq_score), 4) as avg_dq_score
FROM stg_energy_measurements
ORDER BY avg_dq_score DESC;
