-- Базовый тест для Data Quality проверок в ClickHouse
-- Этот файл содержит примеры тестов для проверки качества данных

-- Тест на полноту данных (completeness)
-- Проверяет, что определенный процент строк содержит непустые значения
{% test completeness(model, column_name, threshold=0.95) %}

with validation as (
  select
    count(*) as total_rows,
    count({{ column_name }}) as non_null_rows,
    round(count({{ column_name }}) * 100.0 / count(*), 2) as completeness_percent
  from {{ model }}
),

validation_errors as (
  select *
  from validation
  where completeness_percent < {{ threshold * 100 }}
)

select *
from validation_errors

{% endtest %}

-- Тест на уникальность (uniqueness)
-- Проверяет, что определенный процент значений в колонке уникален
{% test uniqueness(model, column_name, threshold=0.99) %}

with validation as (
  select
    count(*) as total_rows,
    count(distinct {{ column_name }}) as unique_values,
    round(count(distinct {{ column_name }}) * 100.0 / count(*), 2) as uniqueness_percent
  from {{ model }}
),

validation_errors as (
  select *
  from validation
  where uniqueness_percent < {{ threshold * 100 }}
)

select *
from validation_errors

{% endtest %}

-- Тест на диапазон значений (value_range)
-- Проверяет, что все значения находятся в заданном диапазоне
{% test value_range(model, column_name, min_value, max_value) %}

with validation as (
  select
    count(*) as total_rows,
    count(case when {{ column_name }} >= {{ min_value }} and {{ column_name }} <= {{ max_value }} then 1 end) as valid_rows,
    round(count(case when {{ column_name }} >= {{ min_value }} and {{ column_name }} <= {{ max_value }} then 1 end) * 100.0 / count(*), 2) as valid_percent
  from {{ model }}
),

validation_errors as (
  select *
  from validation
  where valid_percent < 100
)

select *
from validation_errors

{% endtest %}

-- Тест на формат даты (date_format)
-- Проверяет, что все значения в колонке являются валидными датами
{% test date_format(model, column_name) %}

with validation as (
  select
    count(*) as total_rows,
    count(case when toDate({{ column_name }}) is not null then 1 end) as valid_dates,
    round(count(case when toDate({{ column_name }}) is not null then 1 end) * 100.0 / count(*), 2) as valid_percent
  from {{ model }}
),

validation_errors as (
  select *
  from validation
  where valid_percent < 100
)

select *
from validation_errors

{% endtest %}

-- Тест на ссылочную целостность (referential_integrity)
-- Проверяет, что все значения внешнего ключа существуют в родительской таблице
{% test referential_integrity(model, fk_column, pk_table, pk_column, threshold=0.99) %}

with validation as (
  select
    count(*) as total_fk_rows,
    count(case when fk.{{ fk_column }} in (select {{ pk_column }} from {{ pk_table }}) then 1 end) as valid_fk_rows,
    round(count(case when fk.{{ fk_column }} in (select {{ pk_column }} from {{ pk_table }}) then 1 end) * 100.0 / count(*), 2) as integrity_percent
  from {{ model }} fk
),

validation_errors as (
  select *
  from validation
  where integrity_percent < {{ threshold * 100 }}
)

select *
from validation_errors

{% endtest %}

-- Тест на отсутствие дубликатов (no_duplicates)
-- Проверяет, что в таблице нет дублирующихся строк
{% test no_duplicates(model, column_names) %}

with validation as (
  select
    count(*) as total_rows,
    count(distinct {{ column_names }}) as unique_rows,
    round(count(distinct {{ column_names }}) * 100.0 / count(*), 2) as uniqueness_percent
  from {{ model }}
),

validation_errors as (
  select *
  from validation
  where uniqueness_percent < 100
)

select *
from validation_errors

{% endtest %}

-- Тест на согласованность данных (data_consistency)
-- Проверяет, что данные соответствуют бизнес-правилам
{% test data_consistency(model, column_name, business_rule) %}

with validation as (
  select
    count(*) as total_rows,
    count(case when {{ business_rule }} then 1 end) as valid_rows,
    round(count(case when {{ business_rule }} then 1 end) * 100.0 / count(*), 2) as consistency_percent
  from {{ model }}
),

validation_errors as (
  select *
  from validation
  where consistency_percent < 100
)

select *
from validation_errors

{% endtest %}
