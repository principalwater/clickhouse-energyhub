# Конвенция именования кластерных таблиц ClickHouse EnergyHub

## Обзор

В ClickHouse EnergyHub используется специальная конвенция именования для кластерных таблиц, которая обеспечивает четкое разделение между локальными (ReplicatedMergeTree) и распределенными (Distributed) таблицами.

## Основные принципы

### 1. Суффикс `_local` для ReplicatedMergeTree таблиц

Все ReplicatedMergeTree таблицы создаются с суффиксом `_local`:

```sql
-- Правильно: таблица с суффиксом _local
CREATE TABLE dim_locations_local ON CLUSTER dwh_prod (
    -- колонки
) ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/otus_default/dim_locations_local/{uuid}', '{replica}');

-- Неправильно: таблица без суффикса _local
CREATE TABLE dim_locations ON CLUSTER dwh_prod (
    -- колонки
) ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/otus_default/dim_locations/{uuid}', '{replica}');
```

### 2. Distributed таблицы без суффикса

Distributed таблицы имеют то же имя, что и основная таблица, но без суффикса `_local`:

```sql
-- Distributed таблица ссылается на _local таблицу
CREATE TABLE dim_locations ON CLUSTER dwh_prod AS dim_locations_local
ENGINE = Distributed(dwh_prod, otus_default, dim_locations_local, cityHash64(location_id));
```

### 3. База данных `otus_default`

Все кластерные таблицы создаются в базе данных `otus_default`:

```sql
-- Создание основной базы данных
CREATE DATABASE IF NOT EXISTS otus_default ON CLUSTER dwh_prod;
```

## Структура путей репликации

### Формат пути для ReplicatedMergeTree

```
/clickhouse/tables/{shard}/otus_default/{table_name}_local/{uuid}
```

Где:
- `{shard}` - автоматически заменяется на номер шарда
- `otus_default` - основная база данных
- `{table_name}_local` - имя таблицы с суффиксом _local
- `{uuid}` - уникальный идентификатор таблицы

### Примеры путей

| Таблица | Путь репликации |
|---------|-----------------|
| `dim_locations_local` | `/clickhouse/tables/{shard}/otus_default/dim_locations_local/{uuid}` |
| `fact_energy_consumption_local` | `/clickhouse/tables/{shard}/otus_default/fact_energy_consumption_local/{uuid}` |
| `daily_energy_summary_local` | `/clickhouse/tables/{shard}/otus_default/daily_energy_summary_local/{uuid}` |

## Макросы для автоматизации

### `clickhouse_replicated_engine`

Автоматически создает ENGINE для ReplicatedMergeTree с правильным путем:

```sql
{{ clickhouse_replicated_engine(
    engine_type='MergeTree',
    order_by='id',
    partition_by='PARTITION BY toYYYYMM(created_at)'
) }}
```

Результат:
```sql
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/otus_default/table_name_local/{uuid}', '{replica}')
ORDER BY id
PARTITION BY toYYYYMM(created_at)
```

### `clickhouse_distributed_engine`

Создает ENGINE для Distributed таблиц:

```sql
{{ clickhouse_distributed_engine('dim_locations', 'cityHash64(location_id)') }}
```

Результат:
```sql
ENGINE = Distributed(dwh_prod, otus_default, dim_locations_local, cityHash64(location_id))
```

### `create_replicated_table`

Создает полную ReplicatedMergeTree таблицу с суффиксом _local:

```sql
{{ create_replicated_table(
    'dim_locations',
    columns=[...],
    order_by='id'
) }}
```

### `create_distributed_table`

Создает Distributed таблицу, ссылающуюся на _local таблицу:

```sql
{{ create_distributed_table('dim_locations', 'dim_locations', 'cityHash64(id)') }}
```

## Примеры использования

### Создание пары таблиц

```sql
-- 1. Создание ReplicatedMergeTree таблицы
{{ create_replicated_table(
    'fact_energy_consumption',
    columns=[
        {'name': 'date_key', 'type': 'Date'},
        {'name': 'device_id', 'type': 'UInt32'},
        {'name': 'total_consumption', 'type': 'Float64'}
    ],
    order_by='(date_key, device_id)',
    partition_by='PARTITION BY toYYYYMM(date_key)'
) }}

-- 2. Создание Distributed таблицы
{{ create_distributed_table(
    'fact_energy_consumption',
    'fact_energy_consumption',
    'cityHash64(device_id)'
) }}
```

### Результат

Создаются две таблицы:
1. `fact_energy_consumption_local` (ReplicatedMergeTree)
2. `fact_energy_consumption` (Distributed)

## Преимущества конвенции

### 1. Четкое разделение ответственности

- `_local` таблицы: хранение данных и репликация
- Без суффикса: распределенные операции и запросы

### 2. Упрощение администрирования

- Легко идентифицировать тип таблицы
- Простое управление репликацией
- Четкая структура путей

### 3. Совместимость с dbt

- Автоматическое создание пар таблиц
- Единообразное именование
- Простота использования в моделях

### 4. Масштабируемость

- Легко добавлять новые шарды
- Простое управление репликами
- Гибкая настройка шардирования

## Рекомендации по использованию

### 1. Всегда используйте макросы

```sql
-- Хорошо: использование макросов
{{ create_replicated_table('table_name', columns, order_by='id') }}

-- Плохо: ручное создание
CREATE TABLE table_name_local ON CLUSTER dwh_prod (...)
```

### 2. Следуйте конвенции именования

```sql
-- Хорошо: четкое разделение
dim_locations_local → dim_locations
fact_energy_consumption_local → fact_energy_consumption

-- Плохо: смешанное именование
dim_locations → dim_locations_distributed
fact_energy_consumption → fact_energy_consumption_distributed
```

### 3. Используйте правильные ссылки

```sql
-- Хорошо: Distributed ссылается на _local
ENGINE = Distributed(dwh_prod, otus_default, table_name_local, sharding_key)

-- Плохо: неправильная ссылка
ENGINE = Distributed(dwh_prod, dds, table_name, sharding_key)
```

### 4. Документируйте изменения

```sql
-- Добавляйте комментарии к таблицам
CREATE TABLE dim_locations_local ON CLUSTER dwh_prod (
    -- колонки
) COMMENT 'Dimension таблица локаций (ReplicatedMergeTree)';

CREATE TABLE dim_locations ON CLUSTER dwh_prod AS dim_locations_local
COMMENT 'Distributed таблица для запросов к локациям';
```

## Troubleshooting

### Частые ошибки

1. **Отсутствие суффикса _local**
   ```
   Error: Table 'table_name' already exists
   ```
   Решение: Используйте суффикс _local для ReplicatedMergeTree таблиц

2. **Неправильный путь репликации**
   ```
   Error: ZooKeeper path does not exist
   ```
   Решение: Убедитесь, что путь содержит `otus_default/{table_name}_local`

3. **Неправильная ссылка в Distributed**
   ```
   Error: Table 'table_name' not found
   ```
   Решение: Distributed таблица должна ссылаться на `table_name_local`

### Проверка структуры

```sql
-- Проверка ReplicatedMergeTree таблиц
SELECT name, engine, total_rows 
FROM system.tables 
WHERE database = 'dds' AND name LIKE '%_local';

-- Проверка Distributed таблиц
SELECT name, engine, total_rows 
FROM system.tables 
WHERE database = 'dds' AND engine = 'Distributed';

-- Проверка путей репликации
SELECT name, engine_full 
FROM system.tables 
WHERE database = 'dds' AND engine LIKE 'Replicated%';
```

## Заключение

Конвенция именования с суффиксом `_local` обеспечивает:
- Четкое разделение между типами таблиц
- Простоту администрирования
- Совместимость с dbt
- Масштабируемость кластера

Следуйте этим принципам для создания надежной и понятной архитектуры кластерных таблиц в ClickHouse EnergyHub.
