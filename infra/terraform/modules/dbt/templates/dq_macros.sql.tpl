# Макросы для Data Quality проверок в ClickHouse
# Этот файл содержит базовые макросы для проверки качества данных

# Макрос для проверки полноты данных
{% macro check_completeness(column_name, table_name, threshold=0.95) %}
  {% set query %}
    SELECT 
      COUNT(*) as total_rows,
      COUNT({{ column_name }}) as non_null_rows,
      ROUND(COUNT({{ column_name }}) * 100.0 / COUNT(*), 2) as completeness_percent
    FROM {{ table_name }}
    WHERE {{ column_name }} IS NOT NULL
  {% endset %}
  
  {% set result = run_query(query) %}
  {% if result.columns[2].values()[0] < threshold * 100 %}
    {{ exceptions.raise_compiler_error("Completeness check failed for " ~ column_name ~ " in " ~ table_name ~ ". Expected: " ~ (threshold * 100) ~ "%, Got: " ~ result.columns[2].values()[0] ~ "%") }}
  {% endif %}
{% endmacro %}

# Макрос для проверки уникальности
{% macro check_uniqueness(column_name, table_name, threshold=0.99) %}
  {% set query %}
    SELECT 
      COUNT(*) as total_rows,
      COUNT(DISTINCT {{ column_name }}) as unique_values,
      ROUND(COUNT(DISTINCT {{ column_name }}) * 100.0 / COUNT(*), 2) as uniqueness_percent
    FROM {{ table_name }}
  {% endset %}
  
  {% set result = run_query(query) %}
  {% if result.columns[2].values()[0] < threshold * 100 %}
    {{ exceptions.raise_compiler_error("Uniqueness check failed for " ~ column_name ~ " in " ~ table_name ~ ". Expected: " ~ (threshold * 100) ~ "%, Got: " ~ result.columns[2].values()[0] ~ "%") }}
  {% endif %}
{% endmacro %}

# Макрос для проверки диапазона значений
{% macro check_value_range(column_name, table_name, min_value, max_value) %}
  {% set query %}
    SELECT 
      COUNT(*) as total_rows,
      COUNT(CASE WHEN {{ column_name }} >= {{ min_value }} AND {{ column_name }} <= {{ max_value }} THEN 1 END) as valid_rows,
      ROUND(COUNT(CASE WHEN {{ column_name }} >= {{ min_value }} AND {{ column_name }} <= {{ max_value }} THEN 1 END) * 100.0 / COUNT(*), 2) as valid_percent
    FROM {{ table_name }}
  {% endset %}
  
  {% set result = run_query(query) %}
  {% if result.columns[2].values()[0] < 100 %}
    {{ exceptions.raise_compiler_error("Value range check failed for " ~ column_name ~ " in " ~ table_name ~ ". Expected all values between " ~ min_value ~ " and " ~ max_value ~ ", Got: " ~ result.columns[2].values()[0] ~ "% valid") }}
  {% endif %}
{% endmacro %}

# Макрос для проверки формата даты
{% macro check_date_format(column_name, table_name, expected_format='%Y-%m-%d') %}
  {% set query %}
    SELECT 
      COUNT(*) as total_rows,
      COUNT(CASE WHEN toDate({{ column_name }}) IS NOT NULL THEN 1 END) as valid_dates,
      ROUND(COUNT(CASE WHEN toDate({{ column_name }}) IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2) as valid_percent
    FROM {{ table_name }}
  {% endset %}
  
  {% set result = run_query(query) %}
  {% if result.columns[2].values()[0] < 100 %}
    {{ exceptions.raise_compiler_error("Date format check failed for " ~ column_name ~ " in " ~ table_name ~ ". Expected format: " ~ expected_format ~ ", Got: " ~ result.columns[2].values()[0] ~ "% valid") }}
  {% endif %}
{% endmacro %}

# Макрос для проверки ссылочной целостности
{% macro check_referential_integrity(fk_column, pk_table, pk_column, threshold=0.99) %}
  {% set query %}
    SELECT 
      COUNT(*) as total_fk_rows,
      COUNT(CASE WHEN fk.{{ fk_column }} IN (SELECT {{ pk_column }} FROM {{ pk_table }}) THEN 1 END) as valid_fk_rows,
      ROUND(COUNT(CASE WHEN fk.{{ fk_column }} IN (SELECT {{ pk_column }} FROM {{ pk_table }}) THEN 1 END) * 100.0 / COUNT(*), 2) as integrity_percent
    FROM {{ this }} fk
  {% endset %}
  
  {% set result = run_query(query) %}
  {% if result.columns[2].values()[0] < threshold * 100 %}
    {{ exceptions.raise_compiler_error("Referential integrity check failed for " ~ fk_column ~ " referencing " ~ pk_table ~ "." ~ pk_column ~ ". Expected: " ~ (threshold * 100) ~ "%, Got: " ~ result.columns[2].values()[0] ~ "%") }}
  {% endif %}
{% endmacro %}

# Макрос для проверки статистики данных
{% macro check_data_statistics(column_name, table_name) %}
  {% set query %}
    SELECT 
      COUNT(*) as total_rows,
      COUNT({{ column_name }}) as non_null_rows,
      AVG({{ column_name }}) as avg_value,
      MIN({{ column_name }}) as min_value,
      MAX({{ column_name }}) as max_value,
      STDDEV({{ column_name }}) as stddev_value
    FROM {{ table_name }}
    WHERE {{ column_name }} IS NOT NULL
  {% endset %}
  
  {{ log("Data statistics for " ~ column_name ~ " in " ~ table_name ~ ":", info=true) }}
  {{ log(query, info=true) }}
{% endmacro %}
