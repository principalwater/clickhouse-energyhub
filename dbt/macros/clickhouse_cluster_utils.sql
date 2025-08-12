-- Макросы для работы с кластером ClickHouse
-- Поддержка ReplicatedMergeTree и Distributed таблиц

{% macro clickhouse_cluster_name() %}
  {{ return('dwh_prod') }}
{% endmacro %}

{% macro clickhouse_replicated_engine(engine_type='MergeTree', order_by=None, partition_by=None, settings=None) %}
  {% set engine_sql %}
    ENGINE = Replicated{{ engine_type }}('/clickhouse/tables/{shard}/otus_default/{{ this.name }}_local/{{ modules.uuid.uuid4() }}', '{replica}')
    {% if order_by %}
      ORDER BY {{ order_by }}
    {% endif %}
    {% if partition_by %}
      {{ partition_by }}
    {% endif %}
    {% if settings %}
      SETTINGS {{ settings }}
    {% endif %}
  {% endset %}
  
  {{ return(engine_sql) }}
{% endmacro %}

{% macro clickhouse_distributed_engine(table_name, sharding_key=None, policy=None) %}
  {% set distributed_sql %}
    ENGINE = Distributed({{ clickhouse_cluster_name() }}, otus_default, {{ table_name }}_local
    {% if sharding_key %}, {{ sharding_key }}{% endif %}
    {% if policy %}, {{ policy }}{% endif %}
    )
  {% endset %}
  
  {{ return(distributed_sql) }}
{% endmacro %}

{% macro create_replicated_table(table_name, columns, engine_type='MergeTree', order_by=None, partition_by=None, settings=None) %}
  {% set create_sql %}
    CREATE TABLE IF NOT EXISTS {{ table_name }}_local ON CLUSTER {{ clickhouse_cluster_name() }} (
      {% for column in columns %}
        {{ column.name }} {{ column.type }}{% if column.default %} DEFAULT {{ column.default }}{% endif %}{% if not loop.last %},{% endif %}
      {% endfor %}
    ) ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/otus_default/{{ table_name }}_local', '{replica}')
    {% if order_by %}
      ORDER BY {{ order_by }}
    {% endif %}
    {% if partition_by %}
      {{ partition_by }}
    {% endif %}
    {% if settings %}
      SETTINGS {{ settings }}
    {% endif %}
  {% endset %}
  
  {{ return(create_sql) }}
{% endmacro %}

{% macro create_distributed_table(table_name, source_table, sharding_key=None, policy=None) %}
  {% set create_sql %}
    CREATE TABLE IF NOT EXISTS {{ table_name }} ON CLUSTER {{ clickhouse_cluster_name() }} AS {{ source_table }}_local
    {{ clickhouse_distributed_engine(source_table, sharding_key, policy) }}
  {% endset %}
  
  {{ return(create_sql) }}
{% endmacro %}

{% macro clickhouse_cluster_insert_strategy() %}
  {% set strategy %}
    {% if target.type == 'cluster' %}
      -- Для кластера используем Distributed таблицу
      INSERT INTO {{ this }}_distributed
      SELECT * FROM {{ this }}
    {% else %}
      -- Для локальной разработки используем обычную таблицу
      INSERT INTO {{ this }}
      SELECT * FROM {{ this }}
    {% endif %}
  {% endset %}
  
  {{ return(strategy) }}
{% endmacro %}

{% macro clickhouse_cluster_select_strategy() %}
  {% set strategy %}
    {% if target.type == 'cluster' %}
      -- Для кластера используем Distributed таблицу
      FROM {{ this }}_distributed
    {% else %}
      -- Для локальной разработки используем обычную таблицу
      FROM {{ this }}
    {% endif %}
  {% endset %}
  
  {{ return(strategy) }}
{% endmacro %}

{% macro clickhouse_cluster_materialization_strategy() %}
  {% set strategy %}
    {% if target.type == 'cluster' %}
      -- Для кластера создаем ReplicatedMergeTree + Distributed
      {{ config(materialized='table') }}
    {% else %}
      -- Для локальной разработки используем обычную таблицу
      {{ config(materialized='table') }}
    {% endif %}
  {% endset %}
  
  {{ return(strategy) }}
{% endmacro %}

{% macro clickhouse_cluster_partition_strategy(column_name, partition_type='monthly') %}
  {% set partition_sql %}
    {% if partition_type == 'daily' %}
      PARTITION BY toDate({{ column_name }})
    {% elif partition_type == 'monthly' %}
      PARTITION BY toYYYYMM({{ column_name }})
    {% elif partition_type == 'yearly' %}
      PARTITION BY toYear({{ column_name }})
    {% elif partition_type == 'shard' %}
      PARTITION BY cityHash64({{ column_name }}) % 2
    {% else %}
      PARTITION BY toYYYYMM({{ column_name }})
    {% endif %}
  {% endset %}
  
  {{ return(partition_sql) }}
{% endmacro %}

{% macro clickhouse_cluster_sharding_key(columns) %}
  {% set sharding_sql %}
    cityHash64(
      {% for column in columns %}
        {{ column }}{% if not loop.last %} || '|' || {% endif %}
      {% endfor %}
    )
  {% endset %}
  
  {{ return(sharding_sql) }}
{% endmacro %}

{% macro clickhouse_cluster_replication_settings() %}
  {% set settings %}
    SETTINGS
      -- Настройки репликации
      replication_alter_partitions_sync = 2,
      -- Настройки сжатия
      compression_codec = 'ZSTD(3)',
      -- Настройки слияния
      merge_with_ttl_timeout = 86400,
      -- Настройки индексов
      min_bytes_for_wide_part = 0,
      min_rows_for_wide_part = 0
  {% endset %}
  
  {{ return(settings) }}
{% endmacro %}

{% macro clickhouse_cluster_optimization_settings() %}
  {% set settings %}
    SETTINGS
      -- Оптимизация запросов
      optimize_aggregation_in_order = 1,
      optimize_read_in_order = 1,
      -- Настройки памяти
      max_memory_usage = 10737418240, -- 10GB
      max_bytes_before_external_group_by = 10737418240, -- 10GB
      -- Настройки параллелизма
      max_threads = 8,
      max_insert_threads = 4
  {% endset %}
  
  {{ return(settings) }}
{% endmacro %}

{% macro clickhouse_cluster_backup_strategy() %}
  {% set backup_sql %}
    -- Стратегия бэкапа для кластера
    BACKUP TABLE {{ this }} TO 's3://backup-bucket/{{ this.name }}/{{ run_started_at.strftime('%Y%m%d') }}'
    SETTINGS
      compression_method = 'zstd',
      compression_level = 3
  {% endset %}
  
  {{ return(backup_sql) }}
{% endmacro %}

{% macro clickhouse_cluster_health_check() %}
  {% set health_sql %}
    -- Проверка здоровья кластера
    SELECT 
      host,
      port,
      database,
      table,
      total_rows,
      total_bytes,
      is_readonly,
      error_count
    FROM system.replicas
    WHERE database = '{{ target.database }}'
    ORDER BY host, port
  {% endset %}
  
  {{ return(health_sql) }}
{% endmacro %}

-- Макросы для операций с кластером
{% macro clickhouse_cluster_alter_table(table_name, operation, params=None) %}
  {% set alter_sql %}
    ALTER TABLE {{ table_name }} ON CLUSTER {{ clickhouse_cluster_name() }} {{ operation }}
    {% if params %}
      {{ params }}
    {% endif %}
  {% endset %}
  
  {{ return(alter_sql) }}
{% endmacro %}

{% macro clickhouse_cluster_drop_table(table_name) %}
  {% set drop_sql %}
    DROP TABLE IF EXISTS {{ table_name }} ON CLUSTER {{ clickhouse_cluster_name() }}
  {% endset %}
  
  {{ return(drop_sql) }}
{% endmacro %}

{% macro clickhouse_cluster_delete_from(table_name, where_condition) %}
  {% set delete_sql %}
    ALTER TABLE {{ table_name }} ON CLUSTER {{ clickhouse_cluster_name() }} DELETE WHERE {{ where_condition }}
  {% endset %}
  
  {{ return(delete_sql) }}
{% endmacro %}

{% macro clickhouse_cluster_update(table_name, set_values, where_condition) %}
  {% set update_sql %}
    ALTER TABLE {{ table_name }} ON CLUSTER {{ clickhouse_cluster_name() }} UPDATE {{ set_values }} WHERE {{ where_condition }}
  {% endset %}
  
  {{ return(update_sql) }}
{% endmacro %}

{% macro clickhouse_cluster_add_column(table_name, column_name, column_type, after_column=None) %}
  {% set add_column_sql %}
    ALTER TABLE {{ table_name }} ON CLUSTER {{ clickhouse_cluster_name() }} 
    ADD COLUMN {{ column_name }} {{ column_type }}
    {% if after_column %} AFTER {{ after_column }}{% endif %}
  {% endset %}
  
  {{ return(add_column_sql) }}
{% endmacro %}

{% macro clickhouse_cluster_drop_column(table_name, column_name) %}
  {% set drop_column_sql %}
    ALTER TABLE {{ table_name }} ON CLUSTER {{ clickhouse_cluster_name() }} DROP COLUMN {{ column_name }}
  {% endset %}
  
  {{ return(drop_column_sql) }}
{% endmacro %}

{% macro clickhouse_cluster_modify_column(table_name, column_name, new_type) %}
  {% set modify_column_sql %}
    ALTER TABLE {{ table_name }} ON CLUSTER {{ clickhouse_cluster_name() }} 
    MODIFY COLUMN {{ column_name }} {{ new_type }}
  {% endset %}
  
  {{ return(modify_column_sql) }}
{% endmacro %}

{% macro clickhouse_cluster_optimize_table(table_name, partition=None) %}
  {% set optimize_sql %}
    OPTIMIZE TABLE {{ table_name }} ON CLUSTER {{ clickhouse_cluster_name() }}
    {% if partition %} PARTITION {{ partition }}{% endif %}
    FINAL
  {% endset %}
  
  {{ return(optimize_sql) }}
{% endmacro %}

{% macro clickhouse_cluster_truncate_table(table_name) %}
  {% set truncate_sql %}
    TRUNCATE TABLE {{ table_name }} ON CLUSTER {{ clickhouse_cluster_name() }}
  {% endset %}
  
  {{ return(truncate_sql) }}
{% endmacro %}

{% macro clickhouse_cluster_rename_table(old_name, new_name) %}
  {% set rename_sql %}
    RENAME TABLE {{ old_name }} TO {{ new_name }} ON CLUSTER {{ clickhouse_cluster_name() }}
  {% endset %}
  
  {{ return(rename_sql) }}
{% endmacro %}
