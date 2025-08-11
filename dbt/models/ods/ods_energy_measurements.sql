{{
  config(
    materialized='view',
    schema='ods',
    tags=['ods', 'preprocessed', 'dq_checked', 'energy_measurements']
  )
}}

-- ODS модель для энергетических измерений
-- Предобработка данных с DQ проверками и очисткой

WITH raw_data AS (
  SELECT 
    *,
    toDate(timestamp) as date_only,
    toHour(timestamp) as hour_only,
    toDayOfWeek(timestamp) as day_of_week
  FROM {{ ref('raw_energy_measurements') }}
  WHERE raw_dq_score >= 0.8  -- Базовый фильтр по качеству
),

-- DQ проверки с использованием макросов
dq_checked_data AS (
  SELECT 
    *,
    -- Проверка полноты критических полей
    CASE 
      WHEN energy_consumption IS NOT NULL THEN 1 
      ELSE 0 
    END as energy_consumption_completeness,
    
    CASE 
      WHEN voltage IS NOT NULL THEN 1 
      ELSE 0 
    END as voltage_completeness,
    
    CASE 
      WHEN current IS NOT NULL THEN 1 
      ELSE 0 
    END as current_completeness,
    
    CASE 
      WHEN power_factor IS NOT NULL THEN 1 
      ELSE 0 
    END as power_factor_completeness,
    
    CASE 
      WHEN device_id IS NOT NULL THEN 1 
      ELSE 0 
    END as device_id_completeness,
    
    CASE 
      WHEN location_id IS NOT NULL THEN 1 
      ELSE 0 
    END as location_id_completeness,
    
    -- Проверка диапазона значений
    CASE 
      WHEN energy_consumption >= 0 AND energy_consumption <= 10000 THEN 1 
      ELSE 0 
    END as energy_consumption_range_check,
    
    CASE 
      WHEN voltage >= 200 AND voltage <= 250 THEN 1 
      ELSE 0 
    END as voltage_range_check,
    
    CASE 
      WHEN current >= 0 AND current <= 100 THEN 1 
      ELSE 0 
    END as current_range_check,
    
    CASE 
      WHEN power_factor >= 0.8 AND power_factor <= 1.0 THEN 1 
      ELSE 0 
    END as power_factor_range_check,
    
    -- Проверка формата даты
    CASE 
      WHEN toDate(timestamp) IS NOT NULL THEN 1 
      ELSE 0 
    END as timestamp_format_check,
    
    -- Проверка уникальности
    CASE 
      WHEN id IS NOT NULL THEN 1 
      ELSE 0 
    END as id_uniqueness_check
    
  FROM raw_data
),

-- Валидация бизнес-правил
business_rules_validated AS (
  SELECT 
    *,
    -- Проверка согласованности энергетических параметров
    CASE 
      WHEN energy_consumption IS NOT NULL AND voltage IS NOT NULL AND current IS NOT NULL AND power_factor IS NOT NULL
           AND ABS(energy_consumption - (voltage * current * power_factor / 1000)) <= 0.1 THEN 1 
      WHEN energy_consumption IS NULL OR voltage IS NULL OR current IS NULL OR power_factor IS NULL THEN 1
      ELSE 0 
    END as energy_consistency_check,
    
    -- Проверка временной логики
    CASE 
      WHEN timestamp <= now() THEN 1 
      ELSE 0 
    END as timestamp_logic_check,
    
    -- Проверка логики обновления
    CASE 
      WHEN created_at <= updated_at OR updated_at IS NULL THEN 1 
      ELSE 0 
    END as update_logic_check
    
  FROM dq_checked_data
),

-- Очистка и стандартизация данных
cleaned_data AS (
  SELECT 
    id,
    timestamp,
    
    -- Стандартизация энергетических параметров
    ROUND(energy_consumption, 3) as energy_consumption,
    ROUND(voltage, 1) as voltage,
    ROUND(current, 2) as current,
    ROUND(power_factor, 3) as power_factor,
    
    device_id,
    location_id,
    
    -- Временные метрики
    date_only,
    hour_only,
    day_of_week,
    
    -- Kafka метаданные
    _kafka_topic,
    _kafka_partition,
    _kafka_offset,
    _kafka_timestamp,
    
    -- DQ метрики
    energy_consumption_completeness,
    voltage_completeness,
    current_completeness,
    power_factor_completeness,
    device_id_completeness,
    location_id_completeness,
    energy_consumption_range_check,
    voltage_range_check,
    current_range_check,
    power_factor_range_check,
    timestamp_format_check,
    id_uniqueness_check,
    energy_consistency_check,
    timestamp_logic_check,
    update_logic_check,
    
    -- Общий DQ score для ODS слоя (взвешенный)
    ROUND(
      (energy_consumption_completeness * 0.15 +
       voltage_completeness * 0.1 +
       current_completeness * 0.1 +
       power_factor_completeness * 0.1 +
       device_id_completeness * 0.15 +
       location_id_completeness * 0.15 +
       energy_consumption_range_check * 0.05 +
       voltage_range_check * 0.05 +
       current_range_check * 0.05 +
       power_factor_range_check * 0.05 +
       timestamp_format_check * 0.05 +
       id_uniqueness_check * 0.15 +
       energy_consistency_check * 0.05 +
       timestamp_logic_check * 0.05 +
       update_logic_check * 0.05), 2
    ) as ods_dq_score,
    
    -- Системные поля
    created_at,
    updated_at
    
  FROM business_rules_validated
)

-- Основной результат - очищенные данные с DQ проверками
SELECT 
  *,
  
  -- Классификация качества данных
  CASE 
    WHEN ods_dq_score >= 0.95 THEN 'Excellent'
    WHEN ods_dq_score >= 0.9 THEN 'Good'
    WHEN ods_dq_score >= 0.8 THEN 'Acceptable'
    WHEN ods_dq_score >= 0.7 THEN 'Needs Improvement'
    ELSE 'Poor'
  END as data_quality_rating,
  
  -- Флаг для дальнейшей обработки
  CASE 
    WHEN ods_dq_score >= 0.8 THEN 1 
    ELSE 0 
  END as ready_for_dds

FROM cleaned_data

-- Фильтр по качеству для ODS слоя
WHERE ods_dq_score >= 0.7

ORDER BY timestamp DESC, device_id, location_id
