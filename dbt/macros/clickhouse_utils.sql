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

-- Макросы для оптимизации работы с ClickHouse
-- Основаны на официальной документации ClickHouse

-- Макрос для партиционирования по месяцам
{% macro clickhouse_partition_by_month(column_name) %}
    toYYYYMM({{ column_name }})
{% endmacro %}

-- Макрос для партиционирования по дням
{% macro clickhouse_partition_by_day(column_name) %}
    toDate({{ column_name }})
{% endmacro %}

-- Макрос для партиционирования по часам
{% macro clickhouse_partition_by_hour(column_name) %}
    toStartOfHour({{ column_name }})
{% endmacro %}

-- Макрос для оптимизации MergeTree
{% macro clickhouse_merge_tree_settings() %}
    ENGINE = MergeTree()
    PARTITION BY {{ clickhouse_partition_by_month('timestamp') }}
    ORDER BY (device_id, timestamp)
    SETTINGS index_granularity = 8192
{% endmacro %}

-- Макрос для оптимизации ReplicatedMergeTree
{% macro clickhouse_replicated_merge_tree_settings(table_name) %}
    ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/otus_default/{{ table_name }}_local/{uuid}', '{replica}')
    PARTITION BY {{ clickhouse_partition_by_month('timestamp') }}
    ORDER BY (device_id, timestamp)
    SETTINGS index_granularity = 8192
{% endmacro %}

-- Макрос для создания Distributed таблицы
{% macro clickhouse_distributed_table_settings(local_table_name) %}
    ENGINE = Distributed('dwh_prod', 'otus_default', '{{ local_table_name }}_local')
{% endmacro %}

-- Макрос для оптимизации запросов с временными диапазонами
{% macro clickhouse_time_range_filter(column_name, days_back=30) %}
    {{ column_name }} >= now() - INTERVAL {{ days_back }} DAY
{% endmacro %}

-- Макрос для агрегации по временным интервалам
{% macro clickhouse_time_bucket(column_name, interval='1 HOUR') %}
    {% if interval == '1 HOUR' %}
        toStartOfHour({{ column_name }})
    {% elif interval == '1 DAY' %}
        toDate({{ column_name }})
    {% elif interval == '1 MONTH' %}
        toStartOfMonth({{ column_name }})
    {% else %}
        toStartOfHour({{ column_name }})
    {% endif %}
{% endmacro %}

-- Макрос для проверки существования таблицы
{% macro clickhouse_table_exists(table_name, database='otus_default') %}
    {% set query %}
        SELECT count() as table_count
        FROM system.tables 
        WHERE database = '{{ database }}' 
          AND name = '{{ table_name }}'
    {% endset %}
    
    {% set result = run_query(query) %}
    {{ return(result.columns[0].values()[0] > 0) }}
{% endmacro %}

-- Макрос для получения размера таблицы
{% macro clickhouse_table_size(table_name, database='otus_default') %}
    {% set query %}
        SELECT 
            formatReadableSize(sum(bytes)) as size,
            sum(rows) as rows
        FROM system.parts 
        WHERE database = '{{ database }}' 
          AND table = '{{ table_name }}'
          AND active = 1
    {% endset %}
    
    {% set result = run_query(query) %}
    {{ return({
        'size': result.columns[0].values()[0],
        'rows': result.columns[1].values()[0]
    }) }}
{% endmacro %}

-- Макрос для очистки старых партиций
{% macro clickhouse_cleanup_old_partitions(table_name, database='otus_default', days_to_keep=90) %}
    {% set query %}
        ALTER TABLE {{ database }}.{{ table_name }} 
        DROP PARTITION ID '{{ clickhouse_partition_by_month('now() - INTERVAL ' + days_to_keep|string + ' DAY') }}'
    {% endset %}
    
    {{ log("Cleaning up old partitions for table: " ~ table_name, info=true) }}
    {{ run_query(query) }}
{% endmacro %}
