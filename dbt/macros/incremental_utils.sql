-- Макросы для инкрементальной загрузки данных
-- Управление инкрементальными моделями и стратегиями

{% macro incremental_strategy_clickhouse() %}
  {% set strategy %}
    {% if is_incremental() %}
      {% set incremental_sql %}
        WHERE updated_at > (
          SELECT COALESCE(MAX(updated_at), '1970-01-01 00:00:00') 
          FROM {{ this }}
        )
      {% endset %}
      {{ return(incremental_sql) }}
    {% endif %}
  {% endset %}
  
  {{ return(strategy) }}
{% endmacro %}

{% macro get_incremental_columns() %}
  {% set columns = ['updated_at', 'created_at'] %}
  {{ return(columns) }}
{% endmacro %}

{% macro incremental_merge_strategy(target_table, source_table, merge_key) %}
  {% set merge_sql %}
    {% if is_incremental() %}
      ALTER TABLE {{ target_table }} 
      REPLACE PARTITION ID '{{ run_started_at.strftime('%Y%m%d%H%M%S') }}'
      FROM {{ source_table }}
      WHERE {{ merge_key }} >= (
        SELECT COALESCE(MAX({{ merge_key }}), '1970-01-01 00:00:00') 
        FROM {{ target_table }}
      )
    {% else %}
      INSERT INTO {{ target_table }}
      SELECT * FROM {{ source_table }}
    {% endif %}
  {% endset %}
  
  {{ return(merge_sql) }}
{% endmacro %}

{% macro incremental_delete_strategy(target_table, source_table, delete_key) %}
  {% set delete_sql %}
    {% if is_incremental() %}
      ALTER TABLE {{ target_table }} 
      DELETE WHERE {{ delete_key }} IN (
        SELECT {{ delete_key }} FROM {{ source_table }}
        WHERE updated_at > (
          SELECT COALESCE(MAX(updated_at), '1970-01-01 00:00:00') 
          FROM {{ target_table }}
        )
      )
    {% endif %}
  {% endset %}
  
  {{ return(delete_sql) }}
{% endmacro %}

{% macro incremental_upsert_strategy(target_table, source_table, unique_key) %}
  {% set upsert_sql %}
    {% if is_incremental() %}
      INSERT INTO {{ target_table }} 
      SELECT * FROM {{ source_table }}
      WHERE updated_at > (
        SELECT COALESCE(MAX(updated_at), '1970-01-01 00:00:00') 
        FROM {{ target_table }}
      )
      ON DUPLICATE KEY UPDATE
        {% for column in get_incremental_columns() %}
          {{ column }} = VALUES({{ column }}),
        {% endfor %}
        dbt_updated_at = now()
    {% else %}
      INSERT INTO {{ target_table }}
      SELECT * FROM {{ source_table }}
    {% endif %}
  {% endset %}
  
  {{ return(upsert_sql) }}
{% endmacro %}
