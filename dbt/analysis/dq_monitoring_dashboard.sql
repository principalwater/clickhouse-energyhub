-- Анализ для мониторинга Data Quality проверок
-- Этот файл содержит SQL запросы для создания дашборда DQ

-- Общая статистика DQ проверок за последние 7 дней
WITH dq_summary AS (
  SELECT 
    test_date,
    test_type,
    COUNT(*) as total_tests,
    COUNT(CASE WHEN result = 'PASS' THEN 1 END) as passed_tests,
    COUNT(CASE WHEN result = 'FAIL' THEN 1 END) as failed_tests,
    ROUND(COUNT(CASE WHEN result = 'PASS' THEN 1 END) * 100.0 / COUNT(*), 2) as success_rate
  FROM dq_checks.dq_test_summary
  WHERE test_date >= today() - 7
  GROUP BY test_date, test_type
),

-- Статистика по типам тестов
test_type_stats AS (
  SELECT 
    test_type,
    COUNT(*) as total_tests,
    COUNT(CASE WHEN result = 'PASS' THEN 1 END) as passed_tests,
    COUNT(CASE WHEN result = 'FAIL' THEN 1 END) as failed_tests,
    ROUND(COUNT(CASE WHEN result = 'PASS' THEN 1 END) * 100.0 / COUNT(*), 2) as success_rate,
    ROUND(AVG(CASE WHEN result = 'FAIL' THEN 1 ELSE 0 END) * 100, 2) as failure_rate
  FROM dq_checks.dq_test_summary
  WHERE test_date >= today() - 7
  GROUP BY test_type
),

-- Статистика по таблицам
table_stats AS (
  SELECT 
    table_name,
    COUNT(*) as total_tests,
    COUNT(CASE WHEN result = 'PASS' THEN 1 END) as passed_tests,
    COUNT(CASE WHEN result = 'FAIL' THEN 1 END) as failed_tests,
    ROUND(COUNT(CASE WHEN result = 'PASS' THEN 1 END) * 100.0 / COUNT(*), 2) as success_rate
  FROM dq_checks.dq_test_summary
  WHERE test_date >= today() - 7
  GROUP BY table_name
),

-- Тренд успешности тестов по дням
daily_trend AS (
  SELECT 
    test_date,
    COUNT(*) as total_tests,
    COUNT(CASE WHEN result = 'PASS' THEN 1 END) as passed_tests,
    ROUND(COUNT(CASE WHEN result = 'PASS' THEN 1 END) * 100.0 / COUNT(*), 2) as daily_success_rate
  FROM dq_checks.dq_test_summary
  WHERE test_date >= today() - 7
  GROUP BY test_date
  ORDER BY test_date
)

-- Основной результат для дашборда
SELECT 
  'Overall DQ Statistics' as metric_type,
  'Last 7 Days' as time_period,
  COUNT(*) as total_tests,
  COUNT(CASE WHEN result = 'PASS' THEN 1 END) as passed_tests,
  COUNT(CASE WHEN result = 'FAIL' THEN 1 END) as failed_tests,
  ROUND(COUNT(CASE WHEN result = 'PASS' THEN 1 END) * 100.0 / COUNT(*), 2) as overall_success_rate,
  ROUND(COUNT(CASE WHEN result = 'FAIL' THEN 1 END) * 100.0 / COUNT(*), 2) as overall_failure_rate
FROM dq_checks.dq_test_summary
WHERE test_date >= today() - 7

UNION ALL

-- Детализация по типам тестов
SELECT 
  'Test Type Breakdown' as metric_type,
  test_type as time_period,
  total_tests,
  passed_tests,
  failed_tests,
  success_rate as overall_success_rate,
  failure_rate as overall_failure_rate
FROM test_type_stats

UNION ALL

-- Детализация по таблицам
SELECT 
  'Table Breakdown' as metric_type,
  table_name as time_period,
  total_tests,
  passed_tests,
  failed_tests,
  success_rate as overall_success_rate,
  ROUND((100 - success_rate), 2) as overall_failure_rate
FROM table_stats

UNION ALL

-- Тренд по дням
SELECT 
  'Daily Trend' as metric_type,
  toString(test_date) as time_period,
  total_tests,
  passed_tests,
  (total_tests - passed_tests) as failed_tests,
  daily_success_rate as overall_success_rate,
  ROUND((100 - daily_success_rate), 2) as overall_failure_rate
FROM daily_trend

ORDER BY metric_type, time_period;
