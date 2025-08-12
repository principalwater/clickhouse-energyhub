-- Комплексные Data Quality проверки для ClickHouse EnergyHub
-- Расширенные возможности для мониторинга качества данных

{% macro comprehensive_dq_check(table_name, column_name, check_type, expected_value=None, custom_logic=None) %}
  {% set check_id = modules.uuid.uuid4() %}
  {% set check_sql %}
    {% if check_type == 'completeness' %}
      -- Проверка полноты данных
      SELECT 
        '{{ check_id }}' as check_id,
        '{{ table_name }}' as table_name,
        '{{ column_name }}' as column_name,
        'completeness' as check_type,
        '{{ expected_value or "NOT NULL" }}' as expected_value,
        count(*) as total_rows,
        count({{ column_name }}) as non_null_rows,
        count(*) - count({{ column_name }}) as null_rows,
        round(count({{ column_name }}) * 100.0 / count(*), 2) as completeness_percentage,
        CASE 
          WHEN count({{ column_name }}) * 100.0 / count(*) >= {{ expected_value or 95 }} THEN 'PASS'
          ELSE 'FAIL'
        END as result,
        '{{ expected_value or 95 }}%' as threshold,
        now() as check_timestamp
      FROM {{ table_name }}
      
    {% elif check_type == 'range_check' %}
      -- Проверка диапазона значений
      SELECT 
        '{{ check_id }}' as check_id,
        '{{ table_name }}' as table_name,
        '{{ column_name }}' as column_name,
        'range_check' as check_type,
        '{{ expected_value or "Within valid range" }}' as expected_value,
        count(*) as total_rows,
        count(CASE WHEN {{ column_name }} IS NOT NULL THEN 1 END) as valid_rows,
        count(CASE WHEN {{ column_name }} IS NULL OR {{ custom_logic }} THEN 1 END) as invalid_rows,
        round(count(CASE WHEN {{ column_name }} IS NULL OR {{ custom_logic }} THEN 1 END) * 100.0 / count(*), 2) as error_percentage,
        CASE 
          WHEN count(CASE WHEN {{ column_name }} IS NULL OR {{ custom_logic }} THEN 1 END) * 100.0 / count(*) <= 5 THEN 'PASS'
          ELSE 'FAIL'
        END as result,
        '5%' as threshold,
        now() as check_timestamp
      
    {% elif check_type == 'uniqueness' %}
      -- Проверка уникальности
      SELECT 
        '{{ check_id }}' as check_id,
        '{{ table_name }}' as table_name,
        '{{ column_name }}' as column_name,
        'uniqueness' as check_type,
        '{{ expected_value or "Unique values" }}' as expected_value,
        count(*) as total_rows,
        count(DISTINCT {{ column_name }}) as unique_values,
        count(*) - count(DISTINCT {{ column_name }}) as duplicate_rows,
        round((count(*) - count(DISTINCT {{ column_name }})) * 100.0 / count(*), 2) as duplication_percentage,
        CASE 
          WHEN count(*) = count(DISTINCT {{ column_name }}) THEN 'PASS'
          ELSE 'FAIL'
        END as result,
        '100% unique' as threshold,
        now() as check_timestamp
      
    {% elif check_type == 'format_check' %}
      -- Проверка формата данных
      SELECT 
        '{{ check_id }}' as check_id,
        '{{ table_name }}' as table_name,
        '{{ column_name }}' as column_name,
        'format_check' as check_type,
        '{{ expected_value or "Valid format" }}' as expected_value,
        count(*) as total_rows,
        count(CASE WHEN {{ custom_logic }} THEN 1 END) as valid_format_rows,
        count(CASE WHEN NOT {{ custom_logic }} THEN 1 END) as invalid_format_rows,
        round(count(CASE WHEN NOT {{ custom_logic }} THEN 1 END) * 100.0 / count(*), 2) as format_error_percentage,
        CASE 
          WHEN count(CASE WHEN NOT {{ custom_logic }} THEN 1 END) * 100.0 / count(*) <= 5 THEN 'PASS'
          ELSE 'FAIL'
        END as result,
        '5%' as threshold,
        now() as check_timestamp
      
    {% elif check_type == 'business_rule' %}
      -- Проверка бизнес-правил
      SELECT 
        '{{ check_id }}' as check_id,
        '{{ table_name }}' as table_name,
        '{{ column_name }}' as column_name,
        'business_rule' as check_type,
        '{{ expected_value or "Business rule validation" }}' as expected_value,
        count(*) as total_rows,
        count(CASE WHEN {{ custom_logic }} THEN 1 END) as valid_business_rows,
        count(CASE WHEN NOT {{ custom_logic }} THEN 1 END) as invalid_business_rows,
        round(count(CASE WHEN NOT {{ custom_logic }} THEN 1 END) * 100.0 / count(*), 2) as business_error_percentage,
        CASE 
          WHEN count(CASE WHEN NOT {{ custom_logic }} THEN 1 END) * 100.0 / count(*) <= 5 THEN 'PASS'
          ELSE 'FAIL'
        END as result,
        '5%' as threshold,
        now() as check_timestamp
      
    {% else %}
      -- Неизвестный тип проверки
      SELECT 
        '{{ check_id }}' as check_id,
        '{{ table_name }}' as table_name,
        '{{ column_name }}' as column_name,
        'unknown' as check_type,
        '{{ expected_value or "Unknown check type" }}' as expected_value,
        0 as total_rows,
        0 as valid_rows,
        0 as invalid_rows,
        0.0 as error_percentage,
        'ERROR' as result,
        'Unknown check type' as threshold,
        now() as check_timestamp
    {% endif %}
  {% endset %}
  
  {{ return(check_sql) }}
{% endmacro %}

{% macro run_dq_suite(table_name, columns_config) %}
  {% set dq_results = [] %}
  
  {% for column_config in columns_config %}
    {% set column_name = column_config.column %}
    {% set checks = column_config.checks %}
    
    {% for check in checks %}
      {% set check_type = check.type %}
      {% set expected_value = check.expected_value %}
      {% set custom_logic = check.custom_logic %}
      
      {% set check_result = comprehensive_dq_check(table_name, column_name, check_type, expected_value, custom_logic) %}
      {% do dq_results.append(check_result) %}
    {% endfor %}
  {% endfor %}
  
  -- Объединение всех результатов проверок
  {% set combined_sql %}
    {% for result in dq_results %}
      {{ result }}
      {% if not loop.last %}
        UNION ALL
      {% endif %}
    {% endfor %}
    ORDER BY table_name, column_name, check_type
  {% endset %}
  
  {{ return(combined_sql) }}
{% endmacro %}

{% macro calculate_dq_score(table_name, columns_config) %}
  {% set dq_score_sql %}
    WITH dq_results AS (
      {{ run_dq_suite(table_name, columns_config) }}
    ),
    score_calculation AS (
      SELECT 
        table_name,
        count(*) as total_checks,
        count(CASE WHEN result = 'PASS' THEN 1 END) as passed_checks,
        count(CASE WHEN result = 'FAIL' THEN 1 END) as failed_checks,
        round(count(CASE WHEN result = 'PASS' THEN 1 END) * 100.0 / count(*), 2) as success_rate,
        round(count(CASE WHEN result = 'PASS' THEN 1 END) * 1.0 / count(*), 3) as dq_score
      FROM dq_results
      GROUP BY table_name
    )
    SELECT 
      table_name,
      total_checks,
      passed_checks,
      failed_checks,
      success_rate,
      dq_score,
      CASE 
        WHEN dq_score >= 0.95 THEN 'excellent'
        WHEN dq_score >= 0.90 THEN 'good'
        WHEN dq_score >= 0.80 THEN 'fair'
        WHEN dq_score >= 0.70 THEN 'poor'
        ELSE 'critical'
      END as quality_rating,
      now() as calculated_at
    FROM score_calculation
  {% endset %}
  
  {{ return(dq_score_sql) }}
{% endmacro %}

{% macro alert_dq_issues(table_name, severity_threshold=0.8) %}
  {% set alert_sql %}
    WITH dq_summary AS (
      {{ calculate_dq_score(table_name, []) }}
    )
    SELECT 
      'DQ ALERT' as alert_type,
      table_name,
      dq_score,
      quality_rating,
      total_checks,
      failed_checks,
      CASE 
        WHEN dq_score < {{ severity_threshold }} THEN 'HIGH'
        WHEN dq_score < 0.9 THEN 'MEDIUM'
        ELSE 'LOW'
      END as alert_severity,
      CASE 
        WHEN dq_score < {{ severity_threshold }} THEN 'Immediate attention required'
        WHEN dq_score < 0.9 THEN 'Review recommended'
        ELSE 'No action needed'
      END as action_required,
      now() as alert_timestamp
    FROM dq_summary
    WHERE dq_score < 0.95  -- Алерты только для проблемных таблиц
    ORDER BY dq_score ASC
  {% endset %}
  
  {{ return(alert_sql) }}
{% endmacro %}

{% macro create_dq_dashboard_data() %}
  {% set dashboard_sql %}
    WITH daily_dq_summary AS (
      SELECT 
        toDate(check_timestamp) as check_date,
        table_name,
        check_type,
        count(*) as total_checks,
        count(CASE WHEN result = 'PASS' THEN 1 END) as passed_checks,
        count(CASE WHEN result = 'FAIL' THEN 1 END) as failed_checks,
        round(count(CASE WHEN result = 'PASS' THEN 1 END) * 100.0 / count(*), 2) as daily_success_rate
      FROM dq_checks.dq_test_summary
      WHERE check_date >= today() - 30  -- Данные за последний месяц
      GROUP BY check_date, table_name, check_type
    ),
    table_dq_trends AS (
      SELECT 
        table_name,
        avg(daily_success_rate) as avg_success_rate,
        min(daily_success_rate) as min_success_rate,
        max(daily_success_rate) as max_success_rate,
        stddevSamp(daily_success_rate) as success_rate_volatility,
        count(DISTINCT check_date) as days_checked
      FROM daily_dq_summary
      GROUP BY table_name
    ),
    check_type_performance AS (
      SELECT 
        check_type,
        count(*) as total_checks,
        count(CASE WHEN result = 'PASS' THEN 1 END) as passed_checks,
        round(count(CASE WHEN result = 'PASS' THEN 1 END) * 100.0 / count(*), 2) as overall_success_rate
      FROM dq_checks.dq_test_summary
      WHERE check_date >= today() - 7  -- Данные за последнюю неделю
      GROUP BY check_type
    )
    SELECT 
      'table_performance' as data_type,
      table_name,
      avg_success_rate,
      min_success_rate,
      max_success_rate,
      success_rate_volatility,
      days_checked,
      CASE 
        WHEN avg_success_rate >= 95 THEN 'excellent'
        WHEN avg_success_rate >= 90 THEN 'good'
        WHEN avg_success_rate >= 80 THEN 'fair'
        WHEN avg_success_rate >= 70 THEN 'poor'
        ELSE 'critical'
      END as overall_quality_rating
    FROM table_dq_trends
    UNION ALL
    SELECT 
      'check_type_performance' as data_type,
      check_type as table_name,
      overall_success_rate as avg_success_rate,
      overall_success_rate as min_success_rate,
      overall_success_rate as max_success_rate,
      0.0 as success_rate_volatility,
      total_checks as days_checked,
      CASE 
        WHEN overall_success_rate >= 95 THEN 'excellent'
        WHEN overall_success_rate >= 90 THEN 'good'
        WHEN overall_success_rate >= 80 THEN 'fair'
        WHEN overall_success_rate >= 70 THEN 'poor'
        ELSE 'critical'
      END as overall_quality_rating
    FROM check_type_performance
    ORDER BY data_type, avg_success_rate DESC
  {% endset %}
  
  {{ return(dashboard_sql) }}
{% endmacro %}
