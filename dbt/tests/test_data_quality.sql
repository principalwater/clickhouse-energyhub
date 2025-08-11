-- Тесты для проверки качества данных
-- Проверка целостности и корректности данных

-- Тест на полноту критических полей
{% test not_null_critical_fields(model, column_name) %}
  SELECT *
  FROM {{ model }}
  WHERE {{ column_name }} IS NULL
{% endtest %}

-- Тест на уникальность ключевых полей
{% test unique_key_fields(model, column_name) %}
  SELECT {{ column_name }}, COUNT(*) as count
  FROM {{ model }}
  GROUP BY {{ column_name }}
  HAVING COUNT(*) > 1
{% endtest %}

-- Тест на диапазон значений
{% test value_range_check(model, column_name, min_value, max_value) %}
  SELECT *
  FROM {{ model }}
  WHERE {{ column_name }} < {{ min_value }} OR {{ column_name }} > {{ max_value }}
{% endtest %}

-- Тест на согласованность данных
{% test data_consistency_check(model, column_name, expected_values) %}
  SELECT *
  FROM {{ model }}
  WHERE {{ column_name }} NOT IN ({{ expected_values | join(', ') }})
{% endtest %}

-- Тест на временную последовательность
{% test temporal_sequence_check(model, timestamp_column) %}
  SELECT *
  FROM {{ model }}
  WHERE {{ timestamp_column }} > now()
{% endtest %}

-- Тест на DQ score
{% test dq_score_threshold(model, dq_score_column, threshold=0.7) %}
  SELECT *
  FROM {{ model }}
  WHERE {{ dq_score_column }} < {{ threshold }}
{% endtest %}
