{{
  config(
    materialized='table',
    schema='dds',
    engine='MergeTree()',
    order_by='timestamp',
    partition_by='toYYYYMM(timestamp)',
    tags=['dds', 'detailed', 'business_logic', 'energy_consumption']
  )
}}

-- DDS модель для детальных данных потребления энергии
-- Применение бизнес-логики и создание детализированных данных

WITH ods_data AS (
  SELECT 
    *,
    toStartOfHour(timestamp) as hour_timestamp,
    toStartOfDay(timestamp) as day_timestamp,
    toStartOfMonth(timestamp) as month_timestamp
  FROM {{ ref('ods_energy_measurements') }}
  WHERE ready_for_dds = 1  -- Только данные, готовые для DDS
),

-- Обогащение данными об устройствах
enriched_with_devices AS (
  SELECT 
    e.*,
    d.device_name,
    d.device_type_id,
    d.power_rating_max,
    d.voltage_standard,
    d.manufacturer,
    d.model,
    d.status as device_status,
    d.installation_date as device_installation_date,
    d.last_maintenance_date as device_last_maintenance,
    d.next_maintenance_date as device_next_maintenance
  FROM ods_data e
  LEFT JOIN {{ ref('dds_devices') }} d ON e.device_id = d.device_id
),

-- Обогащение данными о локациях
enriched_with_locations AS (
  SELECT 
    e.*,
    l.location_name,
    l.region,
    l.city,
    l.timezone,
    l.latitude,
    l.longitude,
    l.country
  FROM enriched_with_devices e
  LEFT JOIN {{ ref('dds_locations') }} l ON e.location_id = l.location_id
),

-- Применение бизнес-правил
business_logic_applied AS (
  SELECT 
    *,
    
    -- Расчет дополнительных энергетических параметров
    ROUND(voltage * current / 1000, 3) as apparent_power_kva,
    ROUND(voltage * current * power_factor / 1000, 3) as real_power_kw,
    ROUND(voltage * current * SQRT(1 - power_factor * power_factor) / 1000, 3) as reactive_power_kvar,
    
    -- Расчет эффективности
    CASE 
      WHEN power_factor >= 0.95 THEN 'High Efficiency'
      WHEN power_factor >= 0.9 THEN 'Good Efficiency'
      WHEN power_factor >= 0.85 THEN 'Acceptable Efficiency'
      ELSE 'Low Efficiency'
    END as efficiency_rating,
    
    -- Расчет нагрузки устройства
    CASE 
      WHEN power_rating_max > 0 
      THEN ROUND((real_power_kw / power_rating_max) * 100, 2)
      ELSE NULL 
    END as device_load_percent,
    
    -- Классификация нагрузки
    CASE 
      WHEN device_load_percent IS NULL THEN 'Unknown'
      WHEN device_load_percent < 25 THEN 'Low Load'
      WHEN device_load_percent < 50 THEN 'Medium Load'
      WHEN device_load_percent < 75 THEN 'High Load'
      WHEN device_load_percent < 90 THEN 'Very High Load'
      ELSE 'Critical Load'
    END as load_classification,
    
    -- Расчет стоимости энергии (примерная)
    ROUND(real_power_kw * 0.15, 4) as estimated_cost_rub_per_hour,  -- 15 руб/кВт*ч
    
    -- Временные классификации
    CASE 
      WHEN hour_timestamp BETWEEN 6 AND 22 THEN 'Day Time'
      ELSE 'Night Time'
    END as time_period,
    
    CASE 
      WHEN day_of_week IN (1, 7) THEN 'Weekend'
      ELSE 'Weekday'
    END as day_type,
    
    CASE 
      WHEN month_timestamp IN (12, 1, 2) THEN 'Winter'
      WHEN month_timestamp IN (3, 4, 5) THEN 'Spring'
      WHEN month_timestamp IN (6, 7, 8) THEN 'Summer'
      ELSE 'Autumn'
    END as season,
    
    -- Аномалии и выбросы
    CASE 
      WHEN energy_consumption > power_rating_max THEN 'Overload'
      WHEN energy_consumption < 0 THEN 'Negative Consumption'
      WHEN voltage < 200 OR voltage > 250 THEN 'Voltage Out of Range'
      WHEN current < 0 OR current > 100 THEN 'Current Out of Range'
      WHEN power_factor < 0.8 OR power_factor > 1.0 THEN 'Power Factor Out of Range'
      ELSE 'Normal'
    END as anomaly_flag,
    
    -- Статус обслуживания устройства
    CASE 
      WHEN device_last_maintenance IS NULL THEN 'Never Maintained'
      WHEN device_next_maintenance IS NULL THEN 'Maintenance Overdue'
      WHEN device_next_maintenance < now() THEN 'Maintenance Overdue'
      WHEN device_next_maintenance <= addDays(now(), 30) THEN 'Maintenance Due Soon'
      WHEN device_next_maintenance <= addDays(now(), 90) THEN 'Maintenance Due'
      ELSE 'Maintenance OK'
    END as maintenance_status
    
  FROM enriched_with_locations
),

-- Агрегация по временным интервалам
time_aggregations AS (
  SELECT 
    *,
    
    -- Почасовая агрегация
    COUNT(*) OVER (
      PARTITION BY hour_timestamp, device_id, location_id
      ORDER BY timestamp
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as measurements_in_hour,
    
    AVG(energy_consumption) OVER (
      PARTITION BY hour_timestamp, device_id, location_id
      ORDER BY timestamp
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as avg_energy_consumption_hour,
    
    -- Дневная агрегация
    COUNT(*) OVER (
      PARTITION BY day_timestamp, device_id, location_id
      ORDER BY timestamp
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as measurements_in_day,
    
    AVG(energy_consumption) OVER (
      PARTITION BY day_timestamp, device_id, location_id
      ORDER BY timestamp
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as avg_energy_consumption_day
    
  FROM business_logic_applied
)

-- Основной результат - детализированные данные с бизнес-логикой
SELECT 
  -- Идентификаторы
  id,
  device_id,
  location_id,
  
  -- Временные метрики
  timestamp,
  hour_timestamp,
  day_timestamp,
  month_timestamp,
  date_only,
  hour_only,
  day_of_week,
  time_period,
  day_type,
  season,
  
  -- Энергетические параметры
  energy_consumption,
  voltage,
  current,
  power_factor,
  apparent_power_kva,
  real_power_kw,
  reactive_power_kvar,
  
  -- Информация об устройстве
  device_name,
  device_type_id,
  power_rating_max,
  voltage_standard,
  manufacturer,
  model,
  device_status,
  device_installation_date,
  device_last_maintenance,
  device_next_maintenance,
  
  -- Информация о локации
  location_name,
  region,
  city,
  timezone,
  latitude,
  longitude,
  country,
  
  -- Бизнес-метрики
  efficiency_rating,
  device_load_percent,
  load_classification,
  estimated_cost_rub_per_hour,
  anomaly_flag,
  maintenance_status,
  
  -- Агрегированные метрики
  measurements_in_hour,
  avg_energy_consumption_hour,
  measurements_in_day,
  avg_energy_consumption_day,
  
  -- DQ метрики
  ods_dq_score,
  data_quality_rating,
  
  -- Kafka метаданные
  _kafka_topic,
  _kafka_partition,
  _kafka_offset,
  _kafka_timestamp,
  
  -- Системные поля
  created_at,
  updated_at,
  '{{ invocation_id }}' as dbt_run_id

FROM time_aggregations

ORDER BY timestamp DESC, device_id, location_id
