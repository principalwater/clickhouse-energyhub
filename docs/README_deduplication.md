# DAG Deduplication Pipeline

## Описание

`deduplication_pipeline` - это автоматизированный DAG в Airflow, который выполняет очистку дублирующихся данных в ClickHouse и автоматически поддерживает актуальность dbt источников.

## Основные возможности

### 🔄 Автоматическое обновление dbt sources
- **Динамическое сканирование** всех таблиц в ClickHouse (raw, ods, dds, cdm)
- **Автоматическая генерация** тестов на основе имен и типов колонок
- **Обновление sources.yml** без необходимости ручного редактирования
- **Интеллектуальное сравнение** существующих и новых таблиц

### 🧹 Система дедупликации данных
- **Удаление дублей** из `raw.river_flow` и `ods.market_data`
- **Создание очищенных таблиц** в слое DDS
- **Использование ROW_NUMBER()** для эффективной дедупликации
- **Создание view** над очищенными данными

### ✅ Автоматизированное тестирование
- **Проверка отсутствия дублей** в очищенных таблицах
- **Валидация качества данных** через dbt тесты
- **Генерация отчетов** по результатам очистки

## Архитектура DAG

```
start → update_dbt_sources → check_duplicates_before → run_dbt_deduplication → run_dbt_views → run_dbt_tests_dedup → check_duplicates_after → generate_dedup_report → end
```

### Детальное описание задач

| Задача                    | Описание                                    | Оператор      | Время выполнения |
|---------------------------|---------------------------------------------|---------------|------------------|
| `update_dbt_sources`      | Автоматическое обновление sources.yml      | PythonOperator| ~5-10 сек        |
| `check_duplicates_before` | Проверка количества дублей до очистки      | PythonOperator| ~2-3 сек         |
| `run_dbt_deduplication`  | Запуск dbt моделей очистки                 | BashOperator  | ~10-30 сек       |
| `run_dbt_views`          | Создание view над очищенными данными       | BashOperator  | ~5-10 сек        |
| `run_dbt_tests_dedup`    | Запуск тестов на отсутствие дублей         | BashOperator  | ~5-15 сек        |
| `check_duplicates_after` | Проверка количества дублей после очистки   | PythonOperator| ~2-3 сек         |
| `generate_dedup_report`  | Генерация отчета по результатам            | PythonOperator| ~2-3 сек         |

## Расписание

**Каждые 5 минут** (`*/5 * * * *`)

## Технические детали

### Модели dbt

#### Очищенные таблицы (tag: clean)
- **`dds_river_flow_clean`** - очищенные данные river_flow без дублей
  - Источник: `raw.river_flow`
  - Ключи дедупликации: `ges_name`, `timestamp`, `river_name`
  - Дополнительные поля: `inserted_at`, `source`

- **`dds_market_data_clean`** - очищенные данные market_data без дублей
  - Источник: `ods.market_data`
  - Ключи дедупликации: `timestamp`, `trading_zone`
  - Дополнительные поля: `inserted_at`, `source`

#### View (tag: view)
- **`dds_river_flow_view`** - представление над `dds_river_flow_clean`
- **`dds_market_data_view`** - представление над `dds_market_data_clean`

### Тесты

#### Автоматически генерируемые тесты
- **`not_null`** - для всех колонок
- **`unique`** - для колонок с "id" в названии
- **`dbt_utils.accepted_range`** - для числовых значений (min_value: 0)
- **`dbt_utils.not_empty_string`** - для строковых колонок

#### Специальные тесты
- **`test_no_duplicates`** - проверка отсутствия дублей в очищенных таблицах

### Логика дедупликации

```sql
-- Пример для river_flow
WITH deduplicated_river_flow AS (
  SELECT 
    ges_name,
    timestamp,
    river_name,
    water_level_m,
    flow_rate_m3_s,
    power_output_mw,
    ROW_NUMBER() OVER (
      PARTITION BY ges_name, timestamp, river_name 
      ORDER BY timestamp DESC
    ) as rn
  FROM raw.river_flow
  WHERE ges_name IS NOT NULL 
    AND timestamp IS NOT NULL 
    AND river_name IS NOT NULL
)

SELECT 
  ges_name,
  timestamp,
  river_name,
  water_level_m,
  flow_rate_m3_s,
  power_output_mw,
  now() as inserted_at,
  'dbt_clean' as source
FROM deduplicated_river_flow
WHERE rn = 1
```

## Мониторинг и логирование

### Логи Airflow
- **Подробные логи** каждой задачи в Airflow UI
- **Время выполнения** каждой задачи
- **Статус выполнения** (Success/Failed)

### Логи dbt
- **Компиляция моделей** с детальными ошибками
- **Результаты выполнения** (PASS/ERROR/SKIP)
- **Время выполнения** каждой модели

### Метрики
- **Количество записей** до и после очистки
- **Количество удаленных дублей**
- **Время выполнения** всего пайплайна

## Устранение неполадок

### Частые проблемы

#### 1. Ошибка компиляции dbt
```
Compilation Error: 'test_not_empty_string' is undefined
```
**Решение**: Убедиться, что установлены зависимости dbt (`dbt deps`)

#### 2. Ошибка ClickHouse
```
Unknown expression identifier `CURRENT_TIMESTAMP`
```
**Решение**: Использовать `now()` вместо `CURRENT_TIMESTAMP` в ClickHouse

#### 3. Ошибка источников
```
Model depends on a source named 'raw.river_flow' which was not found
```
**Решение**: Задача `update_dbt_sources` автоматически исправит это

### Диагностика

#### Проверка статуса DAG
```bash
docker exec airflow-scheduler airflow dags list-runs deduplication_pipeline
```

#### Проверка логов задачи
```bash
# В Airflow UI: DAGs → deduplication_pipeline → Graph → Task → Logs
```

#### Проверка таблиц в ClickHouse
```bash
docker exec clickhouse-01 clickhouse-client --user <ваш_super_user_name> --password '<ваш_super_user_password>' --port 9000 --query "SELECT name FROM system.tables WHERE database = 'dds' ORDER BY name"
```

> **Примечание**: Замените `<ваш_super_user_name>` и `<ваш_super_user_password>` на значения из `terraform.tfvars`

## Интеграция с другими системами

### ClickHouse
- **Автоматическое сканирование** всех баз данных
- **Обновление схемы** при изменении структуры таблиц
- **Поддержка различных движков** таблиц

### dbt
- **Автоматическое обновление** sources.yml
- **Интеграция с тестами** dbt_utils
- **Поддержка различных типов** данных

### Airflow
- **Планировщик задач** с настраиваемым расписанием
- **Мониторинг выполнения** через UI
- **Уведомления об ошибках** и успешном выполнении

## Расширение функциональности

### Добавление новых источников
1. Создать таблицу в соответствующем слое ClickHouse
2. DAG автоматически добавит её в sources.yml
3. Создать dbt модель с тегом `clean`
4. Добавить в DAG при необходимости

### Добавление новых тестов
1. Создать файл теста в `dbt/tests/`
2. Использовать стандартные dbt тесты или dbt_utils
3. Добавить в `schema.yml` для автоматического применения

### Изменение расписания
```python
# В deduplication_pipeline.py
schedule='*/5 * * * *'  # Каждые 5 минут
# Возможные варианты:
# '0 */2 * * *'        # Каждые 2 часа
# '0 0 * * *'          # Ежедневно в полночь
# '0 0 * * 0'          # Еженедельно в воскресенье
```

## Заключение

`deduplication_pipeline` представляет собой полностью автоматизированное решение для:
- **Поддержания актуальности** dbt источников
- **Очистки дублирующихся данных** в ClickHouse
- **Обеспечения качества данных** через автоматизированное тестирование
- **Мониторинга и отчетности** по процессу очистки

Система работает автономно каждые 5 минут, обеспечивая постоянное качество данных в DWH.
