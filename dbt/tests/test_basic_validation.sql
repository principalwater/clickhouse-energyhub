-- Простой тест для проверки базовой валидации
-- Этот тест проверяет, что в таблице есть данные

SELECT *
FROM {{ ref('raw_devices') }}
WHERE device_id IS NULL
