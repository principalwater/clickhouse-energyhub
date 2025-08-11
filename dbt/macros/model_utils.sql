-- Утилитарные макросы для моделей данных
-- Этот файл содержит вспомогательные функции для создания моделей

{% macro generate_schema_name(custom_schema_name, node) %}
  {% if custom_schema_name %}
    {{ return(custom_schema_name) }}
  {% elif node.resource_type == 'model' %}
    {% if node.config.materialized == 'view' %}
      {{ return('staging') }}
    {% elif node.config.materialized == 'table' %}
      {{ return('marts') }}
    {% else %}
      {{ return('intermediate') }}
    {% endif %}
  {% else %}
    {{ return('raw_data') }}
  {% endif %}
{% endmacro %}

{% macro get_table_comment(table_name) %}
  {% set comments = {
    'stg_energy_data': 'Staging модель для энергетических данных с DQ проверками',
    'dim_devices': 'Справочник устройств',
    'dim_locations': 'Справочник локаций',
    'fact_energy_consumption': 'Факты потребления энергии',
    'fact_energy_generation': 'Факты генерации энергии'
  } %}
  {{ return(comments.get(table_name, 'Описание отсутствует')) }}
{% endmacro %}

{% macro get_column_comment(column_name) %}
  {% set comments = {
    'id': 'Уникальный идентификатор',
    'timestamp': 'Временная метка',
    'energy_consumption': 'Потребление энергии в кВт*ч',
    'voltage': 'Напряжение в В',
    'current': 'Ток в А',
    'power_factor': 'Коэффициент мощности',
    'device_id': 'Идентификатор устройства',
    'location_id': 'Идентификатор локации',
    'created_at': 'Время создания записи',
    'updated_at': 'Время обновления записи'
  } %}
  {{ return(comments.get(column_name, 'Описание отсутствует')) }}
{% endmacro %}

{% macro add_standard_columns() %}
  created_at as created_at,
  updated_at as updated_at,
  '{{ invocation_id }}' as dbt_run_id,
  '{{ this }}' as dbt_model_name
{% endmacro %}

{% macro add_dq_columns() %}
  -- Добавляем стандартные DQ колонки
  CASE 
    WHEN energy_consumption IS NOT NULL THEN 1 
    ELSE 0 
  END as energy_consumption_completeness,
  
  CASE 
    WHEN energy_consumption >= 0 AND energy_consumption <= 10000 THEN 1 
    ELSE 0 
  END as energy_consumption_range_check,
  
  CASE 
    WHEN toDate(timestamp) IS NOT NULL THEN 1 
    ELSE 0 
  END as timestamp_format_check,
  
  -- Общий DQ score
  (CASE WHEN energy_consumption IS NOT NULL THEN 1 ELSE 0 END +
   CASE WHEN energy_consumption >= 0 AND energy_consumption <= 10000 THEN 1 ELSE 0 END +
   CASE WHEN toDate(timestamp) IS NOT NULL THEN 1 ELSE 0 END) / 3.0 as dq_score
{% endmacro %}

{% macro get_clickhouse_settings() %}
  {% set settings %}
    SETTINGS 
      use_default_database = 1,
      allow_experimental_object_type = 1,
      allow_experimental_map_type = 1,
      allow_experimental_low_cardinality_type = 1,
      optimize_aggregation_in_order = 1,
      max_threads = 4
  {% endset %}
  {{ return(settings) }}
{% endmacro %}

{% macro get_materialization_config(materialization_type='view') %}
  {% if materialization_type == 'table' %}
    {{ return({
      'materialized': 'table',
      'schema': 'marts',
      'engine': 'MergeTree()',
      'order_by': 'timestamp',
      'partition_by': 'toYYYYMM(timestamp)'
    }) }}
  {% elif materialization_type == 'view' %}
    {{ return({
      'materialized': 'view',
      'schema': 'staging'
    }) }}
  {% else %}
    {{ return({
      'materialized': 'view',
      'schema': 'intermediate'
    }) }}
  {% endif %}
{% endmacro %}

{% macro log_model_execution(model_name, operation='run') %}
  {% set log_message %}
    Executing {{ operation }} for model: {{ model_name }}
    Timestamp: {{ now() }}
    Run ID: {{ invocation_id }}
  {% endset %}
  
  {{ log(log_message, info=true) }}
{% endmacro %}

{% macro validate_model_data(model_name, expected_columns) %}
  {% set validation_query %}
    SELECT 
      COUNT(*) as total_rows,
      {% for column in expected_columns %}
        COUNT({{ column }}) as {{ column }}_count
        {%- if not loop.last %},{% endif %}
      {% endfor %}
    FROM {{ model_name }}
  {% endset %}
  
  {{ log("Validating model: " ~ model_name, info=true) }}
  {{ log(validation_query, info=true) }}
  
  {% set result = run_query(validation_query) %}
  {{ log("Validation result: " ~ result, info=true) }}
{% endmacro %}
