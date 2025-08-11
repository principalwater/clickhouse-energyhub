-- Утилитарные макросы для ClickHouse
-- Специфичные для ClickHouse операции и функции

{% macro clickhouse_partition_by_date(column_name, partition_type='monthly') %}
  {% set partition_sql %}
    {% if partition_type == 'daily' %}
      PARTITION BY toDate({{ column_name }})
    {% elif partition_type == 'monthly' %}
      PARTITION BY toYYYYMM({{ column_name }})
    {% elif partition_type == 'yearly' %}
      PARTITION BY toYear({{ column_name }})
    {% else %}
      PARTITION BY toYYYYMM({{ column_name }})
    {% endif %}
  {% endset %}
  
  {{ return(partition_sql) }}
{% endmacro %}

{% macro clickhouse_engine(engine_type='MergeTree', order_by=None, partition_by=None) %}
  {% set engine_sql %}
    ENGINE = {{ engine_type }}()
    {% if order_by %}
      ORDER BY {{ order_by }}
    {% endif %}
    {% if partition_by %}
      {{ partition_by }}
    {% endif %}
  {% endset %}
  
  {{ return(engine_sql) }}
{% endmacro %}

{% macro clickhouse_index(columns, index_type='minmax') %}
  {% set index_sql %}
    {% for column in columns %}
      INDEX {{ column.name if column.name else 'idx_' ~ column.column }}_{{ loop.index }} 
      {{ column.column }} TYPE {{ column.type if column.type else index_type }} GRANULARITY 1,
    {% endfor %}
  {% endset %}
  
  {{ return(index_sql.rstrip(',')) }}
{% endmacro %}

{% macro clickhouse_incremental_strategy() %}
  {% set strategy %}
    {% if is_incremental() %}
      WHERE {{ this }}.updated_at > (SELECT MAX(updated_at) FROM {{ this }})
    {% endif %}
  {% endset %}
  
  {{ return(strategy) }}
{% endmacro %}

{% macro clickhouse_merge_operation(table_name, source_table, merge_key) %}
  {% set merge_sql %}
    ALTER TABLE {{ table_name }} 
    REPLACE PARTITION ID '{{ run_started_at.strftime('%Y%m%d%H%M%S') }}'
    FROM {{ source_table }}
    WHERE {{ merge_key }} = '{{ run_started_at.strftime('%Y%m%d%H%M%S') }}'
  {% endset %}
  
  {{ return(merge_sql) }}
{% endmacro %}
