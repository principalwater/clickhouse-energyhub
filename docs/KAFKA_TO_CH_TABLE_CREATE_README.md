# Kafka to ClickHouse Table Creation DAG

## Описание

Универсальный DAG `kafka_to_ch_table_create` для динамического создания таблиц ClickHouse из Kafka топиков по схеме:

```
Kafka Topic → Kafka Table Engine → Materialized View → ReplicatedMergeTree/Distributed Table
```

DAG адаптирован под архитектуру DWH с слоями: **raw**, **ods**, **dds**, **cdm**.

## Архитектура DWH

### Слои данных:
- **raw** - сырые данные из источников (Kafka топики)
- **ods** - операционные данные (Operational Data Store)
- **dds** - детализированные данные (Detailed Data Store)
- **cdm** - агрегированные данные (Common Data Model)

### Схема размещения:
```
energy_kafka.{table_name}_kafka (Kafka Engine)
    ↓ Materialized View
{dwh_layer}.{table_name} (Distributed Table)
    ↓
{dwh_layer}.{table_name}_local (ReplicatedMergeTree)
```

## Параметры конфигурации

### Обязательные параметры

| Параметр           | Тип     | Описание                    | Пример                                    |
|--------------------|----------|-----------------------------|-------------------------------------------|
| `kafka_topic`      | string   | Название Kafka топика       | `"energy_data_1min"`                     |
| `target_table_name`| string   | Название целевой таблицы    | `"river_flow"`                           |
| `schema`           | object   | Схема данных (поле → тип)   | `{"timestamp": "String", "value": "Float64"}` |

### Опциональные параметры

| Параметр        | Тип     | По умолчанию              | Описание                                |
|-----------------|----------|---------------------------|-----------------------------------------|
| `dwh_layer`     | string   | `"raw"`                   | Слой DWH: raw, ods, dds, cdm           |
| `sort_key`      | string   | `"timestamp"`             | Ключ сортировки для таблиц              |
| `partition_key` | string   | `"toYYYYMM(timestamp)"`   | Ключ партиционирования                  |
| `shard_key`     | string   | `"xxHash64(timestamp)"`   | Ключ шардирования                       |
| `cluster_name`  | string   | `"dwh_prod"`              | Название кластера ClickHouse            |
| `kafka_broker`  | string   | `"kafka:9092"`            | Адрес Kafka брокера                     |

## Примеры использования

### 1. Создание таблиц для сырых данных речного стока (raw)

```json
{
  "kafka_topic": "energy_data_1min",
  "target_table_name": "river_flow",
  "dwh_layer": "raw",
  "sort_key": "timestamp, river_name",
  "partition_key": "toYYYYMM(timestamp)",
  "shard_key": "xxHash64(river_name)",
  "schema": {
    "timestamp": "String",
    "river_name": "String",
    "ges_name": "String",
    "water_level_m": "Float64",
    "flow_rate_m3_s": "Float64",
    "power_output_mw": "Float64"
  }
}
```

### 2. Создание таблиц для операционных данных (ods)

```json
{
  "kafka_topic": "energy_data_5min",
  "target_table_name": "market_data",
  "dwh_layer": "ods",
  "sort_key": "timestamp, trading_zone",
  "partition_key": "toYYYYMM(timestamp)",
  "shard_key": "xxHash64(trading_zone)",
  "schema": {
    "timestamp": "String",
    "trading_zone": "String",
    "price_eur_mwh": "Float64",
    "volume_mwh": "Float64"
  }
}
```

### 3. Создание таблиц для детализированных данных (dds)

```json
{
  "kafka_topic": "sensor_data",
  "target_table_name": "sensor_readings",
  "dwh_layer": "dds",
  "sort_key": "timestamp, sensor_id",
  "partition_key": "toYYYYMM(timestamp)",
  "shard_key": "xxHash64(sensor_id)",
  "schema": {
    "timestamp": "String",
    "sensor_id": "String",
    "temperature": "Float64",
    "humidity": "Float64",
    "pressure": "Float64",
    "location": "String"
  }
}
```

## Запуск DAG

### Через Airflow UI

1. Перейти к DAG `kafka_to_ch_table_create`
2. Нажать "Trigger DAG"
3. В поле "Configuration JSON" ввести параметры:

```json
{
  "kafka_topic": "your_topic_name",
  "target_table_name": "your_table_name",
  "dwh_layer": "raw",
  "schema": {
    "timestamp": "String",
    "field1": "String",
    "field2": "Float64"
  }
}
```

4. Нажать "Trigger"

### Через Airflow CLI

```bash
airflow dags trigger kafka_to_ch_table_create \
  --conf '{"kafka_topic": "energy_data_1min", "target_table_name": "river_flow", "dwh_layer": "raw", "schema": {"timestamp": "String", "value": "Float64"}}'
```

## Создаваемые объекты

Для каждого запуска DAG создаются:

### 1. Базы данных DWH
- `energy_kafka` - для Kafka-таблиц
- `raw` - для сырых данных
- `ods` - для операционных данных
- `dds` - для детализированных данных
- `cdm` - для агрегированных данных

### 2. Таблицы
- `energy_kafka.{table_name}_kafka` - Kafka-таблица
- `{dwh_layer}.{table_name}_local` - локальная ReplicatedMergeTree таблица с UUID
- `{dwh_layer}.{table_name}` - распределенная таблица

### 3. Materialized View
- `{dwh_layer}.{table_name}_mv` - для доставки данных

### 4. Оптимизации
- Индекс по времени: `idx_timestamp`
- Проекция: `{table_name}_projection`

## Особенности реализации

### UUID в путях таблиц
Локальные таблицы создаются с UUID в пути для уникальности:
```sql
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/{database_name}/{table_name}_local/{uuid}/', '{replica}')
```

### Автоматические преобразования
- `timestamp` поле автоматически преобразуется из `String` в `DateTime`
- Добавляется фильтр `WHERE timestamp != ''` в Materialized View

### Оптимизации по умолчанию
- Партиционирование по месяцам
- Индекс по времени
- Проекции для оптимизации запросов
- Уникальные consumer groups для каждого типа данных

## Задачи DAG

1. **get_table_config** - Получение и валидация параметров
2. **check_connections** - Проверка подключений к ClickHouse и Kafka
3. **generate_sql_script** - Генерация SQL-скрипта на основе параметров
4. **execute_sql_script** - Выполнение SQL-скрипта
5. **verify_data_flow** - Проверка потока данных (30 сек ожидания)
6. **health_check** - Проверка здоровья созданных таблиц

## Мониторинг

### Проверка созданных таблиц

```sql
-- Список всех таблиц для конкретной таблицы
SELECT 
    database,
    table,
    engine,
    total_rows,
    total_bytes
FROM system.tables 
WHERE database IN ('raw', 'ods', 'dds', 'cdm', 'energy_kafka')
AND table LIKE 'your_table_name%'
ORDER BY database, table;
```

### Проверка данных

```sql
-- Количество записей
SELECT count() FROM raw.your_table_name;

-- Последние записи
SELECT * FROM raw.your_table_name ORDER BY timestamp DESC LIMIT 5;
```

### Проверка Materialized View

```sql
-- Статус Materialized View
SELECT 
    database,
    table,
    engine,
    engine_full
FROM system.tables 
WHERE engine = 'MaterializedView' 
AND table LIKE 'your_table_name%';
```

## Рекомендации по использованию слоев

### raw (сырые данные)
- Используйте для данных, которые приходят напрямую из источников
- Минимальная обработка, только парсинг timestamp
- Пример: `energy_data_1min`, `energy_data_5min`

### ods (операционные данные)
- Используйте для данных, которые требуют базовой очистки
- Добавление технических полей, валидация
- Пример: `market_data`, `sensor_data`

### dds (детализированные данные)
- Используйте для данных, которые требуют обогащения
- Связывание с справочниками, расчеты
- Пример: `enriched_sensor_data`, `calculated_metrics`

### cdm (агрегированные данные)
- Используйте для агрегированных данных
- Суммы, средние, группировки по времени
- Пример: `hourly_aggregates`, `daily_summaries`

## Требования

- ClickHouse кластер `dwh_prod`
- Kafka с нужными топиками
- Python библиотеки: `clickhouse-connect`, `kafka-python`
- Права super user в ClickHouse (переменная `super_user_name` из `terraform.tfvars`)

## Безопасность

- Уникальные consumer groups для каждого типа данных
- Партиционирование обеспечивает равномерное распределение нагрузки
- Шардирование по указанному ключу
- Фильтрация некорректных данных в Materialized View
- UUID в путях обеспечивает уникальность таблиц
