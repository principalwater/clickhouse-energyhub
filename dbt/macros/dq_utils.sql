-- Утилитарные макросы для Data Quality проверок
-- Этот файл содержит вспомогательные функции для DQ проверок

{% macro get_dq_threshold(environment='dev') %}
  {% set thresholds = {
    'dev': 0.1,
    'test': 0.2,
    'prod': 0.05
  } %}
  {{ return(thresholds.get(environment, 0.1)) }}
{% endmacro %}

{% macro log_dq_result(test_name, result, expected, actual, severity='info') %}
  {% set log_message %}
    DQ Test: {{ test_name }}
    Expected: {{ expected }}
    Actual: {{ actual }}
    Result: {{ result }}
  {% endset %}
  
  {% if severity == 'error' %}
    {{ log(log_message, info=false) }}
  {% elif severity == 'warn' %}
    {{ log(log_message, info=false) }}
  {% else %}
    {{ log(log_message, info=true) }}
  {% endif %}
{% endmacro %}

{% macro create_dq_summary_table() %}
  {% set create_table_sql %}
    CREATE TABLE IF NOT EXISTS dq_checks.dq_test_summary (
      test_name String,
      test_date Date,
      test_time DateTime,
      table_name String,
      column_name String,
      test_type String,
      expected_value String,
      actual_value String,
      result String,
      severity String,
      error_message String
    ) ENGINE = MergeTree()
    ORDER BY (test_date, test_time)
  {% endset %}
  
  {{ log("Creating DQ summary table", info=true) }}
  {{ run_query(create_table_sql) }}
{% endmacro %}

{% macro insert_dq_result(test_name, table_name, column_name, test_type, expected_value, actual_value, result, severity='info', error_message='') %}
  {% set insert_sql %}
    INSERT INTO dq_checks.dq_test_summary (
      test_name, test_date, test_time, table_name, column_name, 
      test_type, expected_value, actual_value, result, severity, error_message
    ) VALUES (
      '{{ test_name }}',
      today(),
      now(),
      '{{ table_name }}',
      '{{ column_name }}',
      '{{ test_type }}',
      '{{ expected_value }}',
      '{{ actual_value }}',
      '{{ result }}',
      '{{ severity }}',
      '{{ error_message }}'
    )
  {% endset %}
  
  {{ log("Inserting DQ result", info=true) }}
  {{ run_query(insert_sql) }}
{% endmacro %}

{% macro get_dq_statistics(table_name, days_back=7) %}
  {% set stats_sql %}
    SELECT 
      test_type,
      COUNT(*) as total_tests,
      COUNT(CASE WHEN result = 'PASS' THEN 1 END) as passed_tests,
      COUNT(CASE WHEN result = 'FAIL' THEN 1 END) as failed_tests,
      ROUND(COUNT(CASE WHEN result = 'PASS' THEN 1 END) * 100.0 / COUNT(*), 2) as success_rate
    FROM dq_checks.dq_test_summary
    WHERE table_name = '{{ table_name }}'
      AND test_date >= today() - {{ days_back }}
    GROUP BY test_type
    ORDER BY success_rate DESC
  {% endset %}
  
  {{ log("Getting DQ statistics for " ~ table_name, info=true) }}
  {{ return(run_query(stats_sql)) }}
{% endmacro %}

{% macro alert_dq_failure(test_name, table_name, column_name, expected, actual, threshold) %}
  {% set alert_message %}
    DQ FAILURE ALERT:
    Test: {{ test_name }}
    Table: {{ table_name }}
    Column: {{ column_name }}
    Expected: {{ expected }}
    Actual: {{ actual }}
    Threshold: {{ threshold }}
    Time: {{ now() }}
  {% endset %}
  
  {{ log(alert_message, info=false) }}
  
  -- Здесь можно добавить логику отправки уведомлений
  -- Например, через webhook, email или Slack
  {% if var('enable_dq_monitoring', false) %}
    {{ log("DQ monitoring enabled - sending alert", info=true) }}
  {% endif %}
{% endmacro %}

{% macro run_dq_suite(table_name, columns_config) %}
  {% set dq_results = [] %}
  
  {% for column in columns_config %}
    {% set column_name = column.name %}
    {% set tests = column.tests %}
    
    {% for test in tests %}
      {% set test_name = test.name if test.name else 'default_test' %}
      {% set test_type = test.type if test.type else 'generic' %}
      
      {% if test_type == 'completeness' %}
        {% set result = check_completeness(column_name, table_name, test.threshold) %}
        {% set dq_results = dq_results.append({
          'column': column_name,
          'test': test_name,
          'type': test_type,
          'result': result
        }) %}
      {% elif test_type == 'uniqueness' %}
        {% set result = check_uniqueness(column_name, table_name, test.threshold) %}
        {% set dq_results = dq_results.append({
          'column': column_name,
          'test': test_name,
          'type': test_type,
          'result': result
        }) %}
      {% elif test_type == 'value_range' %}
        {% set result = check_value_range(column_name, table_name, test.min_value, test.max_value) %}
        {% set dq_results = dq_results.append({
          'column': column_name,
          'test': test_name,
          'type': test_type,
          'result': result
        }) %}
      {% endif %}
    {% endfor %}
  {% endfor %}
  
  {{ return(dq_results) }}
{% endmacro %}
