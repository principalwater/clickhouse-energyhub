# ClickHouse Backup Pipeline

## Описание

DAG для автоматического создания бэкапов и восстановления ClickHouse. Поддерживает два режима работы:

1. **Режим бэкапа** (по умолчанию): создание, проверка и очистка бэкапов
2. **Режим восстановления**: восстановление из указанного бэкапа

## Режимы работы

### 1. Обычный режим (создание бэкапа)
- **Расписание**: каждый день в 3:00
- **Выполняемые шаги**:
  - `list_backups` - получение списка доступных бэкапов
  - `create_backup` - создание нового бэкапа
  - `verify_backup` - проверка целостности созданного бэкапа
  - `cleanup_old_backups` - очистка старых бэкапов (оставляем последние 7)
  - `health_check` - проверка здоровья системы

### 2. Режим восстановления
- **Активация**: через JSON триггер с параметром `restore_mode: true`
- **Выполняемые шаги**:
  - `list_backups` - получение списка доступных бэкапов
  - `restore_backup` - восстановление из указанного бэкапа
  - `health_check` - проверка здоровья системы

## Использование

### Запуск в режиме восстановления

#### Через Airflow UI:
1. Перейдите в раздел DAGs
2. Найдите `clickhouse_backup_pipeline`
3. Нажмите "Trigger DAG"
4. В поле "Configuration JSON" введите:

**Восстановление из конкретного бэкапа:**
```json
{
  "restore_mode": true,
  "backup_name": "backup_2025_01_15_03_00_00"
}
```

**Восстановление из последнего бэкапа:**
```json
{
  "restore_mode": true
}
```

#### Через CLI:
```bash
# Восстановление из конкретного бэкапа
airflow dags trigger clickhouse_backup_pipeline --conf '{"restore_mode": true, "backup_name": "backup_2025_01_15_03_00_00"}'

# Восстановление из последнего бэкапа
airflow dags trigger clickhouse_backup_pipeline --conf '{"restore_mode": true}'
```

#### Через REST API:
```bash
# Восстановление из конкретного бэкапа
curl -X POST \
  http://localhost:8080/api/v1/dags/clickhouse_backup_pipeline/dagRuns \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Basic <base64_encoded_credentials>' \
  -d '{
    "conf": {
      "restore_mode": true,
      "backup_name": "backup_2025_01_15_03_00_00"
    }
  }'

# Восстановление из последнего бэкапа
curl -X POST \
  http://localhost:8080/api/v1/dags/clickhouse_backup_pipeline/dagRuns \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Basic <base64_encoded_credentials>' \
  -d '{
    "conf": {
      "restore_mode": true
    }
  }'
```

## Параметры

| Параметр      | Тип      | Обязательный | Описание                                                                        |
|---------------|----------|--------------|---------------------------------------------------------------------------------|
| `restore_mode`| boolean  | Нет          | Если `true`, запускается режим восстановления                                   |
| `backup_name` | string   | Нет          | Имя бэкапа для восстановления (по умолчанию используется последний бэкап)        |
| `force_restore`| boolean | Нет          | Принудительное восстановление без проверки изменений (по умолчанию false)        |

## Примеры конфигураций

### Обычный режим (создание бэкапа)
```json
{}
```

### Восстановление из конкретного бэкапа
```json
{
  "restore_mode": true,
  "backup_name": "backup_2025_01_15_03_00_00"
}
```

### Восстановление из последнего бэкапа
```json
{
  "restore_mode": true
}
```

### Принудительное восстановление
```json
{
  "restore_mode": true,
  "force_restore": true
}
```

## Примечания

- В режиме восстановления `backup_name` опционален - если не указан, используется последний доступный бэкап
- Все операции логируются и доступны в Airflow UI
- При ошибке в любой задаче DAG остановится и не будет выполнять последующие шаги
