# Руководство по бэкапам ClickHouse

## Обзор

Система бэкапов ClickHouse использует `clickhouse-backup` для автоматического создания, восстановления и управления резервными копиями данных.

## Компоненты

### 1. DAG для автоматизации
- **Файл:** `airflow/dags/clickhouse_backup_pipeline.py`
- **Расписание:** Каждый день в 3:00
- **Функции:** Создание, проверка, очистка бэкапов

### 2. Менеджер бэкапов
- **Файл:** `scripts/clickhouse_backup_manager.py`
- **Функции:** Ручное управление бэкапами, тестирование

## Автоматические бэкапы

### Расписание
- **Создание:** Каждый день в 3:00
- **Проверка:** Сразу после создания
- **Очистка:** Оставляем последние 7 бэкапов

### Процесс
1. **Создание бэкапа** - уникальное имя с датой и временем
2. **Проверка целостности** - подтверждение успешного создания
3. **Очистка старых** - удаление бэкапов старше 7 дней
4. **Проверка здоровья** - тестирование системы

## Ручное управление

### Использование менеджера бэкапов

```bash
# Создание бэкапа
python scripts/clickhouse_backup_manager.py create

# Создание бэкапа с именем
python scripts/clickhouse_backup_manager.py create --backup-name "my_backup_20250101"

# Список бэкапов
python scripts/clickhouse_backup_manager.py list

# Восстановление из последнего бэкапа
python scripts/clickhouse_backup_manager.py restore

# Восстановление из конкретного бэкапа
python scripts/clickhouse_backup_manager.py restore --backup-name "backup_local_20250101_030000"

# Проверка бэкапа
python scripts/clickhouse_backup_manager.py verify --backup-name "backup_local_20250101_030000"

# Удаление бэкапа
python scripts/clickhouse_backup_manager.py delete --backup-name "backup_local_20250101_030000"

# Очистка старых бэкапов (оставить 5)
python scripts/clickhouse_backup_manager.py cleanup --keep-count 5

# Тестирование системы
python scripts/clickhouse_backup_manager.py health

# Имитация сбоя и восстановления
python scripts/clickhouse_backup_manager.py test --table-name "test_db.sample_table"
```

### Прямые команды Docker

```bash
# Создание бэкапа
docker exec clickhouse-backup clickhouse-backup create_remote "backup_local_$(date +%Y%m%d_%H%M%S)"

# Список бэкапов
docker exec clickhouse-backup clickhouse-backup list remote

# Получение последнего бэкапа
LATEST_BACKUP=$(docker exec clickhouse-backup clickhouse-backup list remote | grep '^backup' | tail -1 | awk '{print $1}')

# Восстановление из бэкапа
docker exec clickhouse-backup clickhouse-backup restore_remote $LATEST_BACKUP

# Удаление бэкапа
docker exec clickhouse-backup clickhouse-backup delete remote "backup_name"
```

## Восстановление через Airflow

### Ручной запуск с параметрами

1. Откройте Airflow UI: http://localhost:8080
2. Найдите DAG `clickhouse_backup_pipeline`
3. Нажмите "Trigger DAG"
4. В параметрах укажите:
   ```json
   {
     "backup_name": "backup_local_20250101_030000"
   }
   ```
5. Выберите только задачи `list_backups` и `restore_backup`

### Программное восстановление

```python
from airflow.models import DagRun
from datetime import datetime

# Создание DAG Run с параметрами
dag_run = DagRun(
    dag_id='clickhouse_backup_pipeline',
    run_id=f'manual_restore_{datetime.now().strftime("%Y%m%d_%H%M%S")}',
    conf={'backup_name': 'backup_local_20250101_030000'},
    external_trigger=True
)
```

## Тестирование восстановления

### Автоматический тест

```bash
# Запуск теста с имитацией сбоя
python scripts/clickhouse_backup_manager.py test
```

### Ручной тест

```bash
# 1. Создаем бэкап
docker exec clickhouse-backup clickhouse-backup create_remote "test_backup_$(date +%Y%m%d_%H%M%S)"

# 2. Имитируем сбой - удаляем таблицу
docker exec -i clickhouse-01 clickhouse-client --user ${TF_VAR_super_user_name} --password ${TF_VAR_super_user_password} --query "DROP TABLE IF EXISTS test_db.sample_table ON CLUSTER dwh_test SYNC;"

# 3. Восстанавливаем из бэкапа
LATEST_BACKUP=$(docker exec clickhouse-backup clickhouse-backup list remote | grep '^test_backup' | tail -1 | awk '{print $1}')
docker exec clickhouse-backup clickhouse-backup restore_remote $LATEST_BACKUP

# 4. Проверяем восстановление
docker exec -i clickhouse-01 clickhouse-client --user ${TF_VAR_super_user_name} --password ${TF_VAR_super_user_password} --query "SELECT count() FROM test_db.sample_table;"
```

## Мониторинг

### Проверка статуса

```bash
# Статус контейнеров
docker ps | grep clickhouse

# Логи clickhouse-backup
docker logs clickhouse-backup

# Проверка здоровья
python scripts/clickhouse_backup_manager.py health
```

### Логи Airflow

- **DAG логи:** В Airflow UI в разделе "Graph" → "Logs"
- **Файлы логов:** `volumes/airflow/logs/`

## Устранение неполадок

### Проблемы с созданием бэкапа

```bash
# Проверка доступности ClickHouse
docker exec clickhouse-01 clickhouse-client --query 'SELECT 1'

# Проверка конфигурации clickhouse-backup
docker exec clickhouse-backup cat /etc/clickhouse-backup/config.yml

# Проверка подключения к S3/MinIO
docker exec clickhouse-backup clickhouse-backup list remote
```

### Проблемы с восстановлением

```bash
# Проверка списка бэкапов
docker exec clickhouse-backup clickhouse-backup list remote

# Проверка целостности бэкапа
docker exec clickhouse-backup clickhouse-backup list remote | grep "backup_name"

# Очистка и повторная попытка
docker exec clickhouse-01 clickhouse-client --query 'SYSTEM DROP MARK CACHE'
docker exec clickhouse-01 clickhouse-client --query 'SYSTEM DROP UNCOMPRESSED CACHE'
```

### Проблемы с Airflow

```bash
# Проверка синтаксиса DAG
docker exec airflow-api-server python -c "
from airflow.models import DagBag
dagbag = DagBag('/opt/airflow/dags')
print('DAGs loaded:', dagbag.dag_ids)
print('Errors:', dagbag.import_errors)
"

# Перезапуск Airflow контейнеров
docker restart airflow-scheduler airflow-api-server
```

## Безопасность

### Переменные окружения

- **CH_USER:** Пользователь ClickHouse (из Terraform.tfvars)
- **CH_PASSWORD:** Пароль ClickHouse (из Terraform.tfvars)

### Доступ к бэкапам

- Бэкапы хранятся в S3/MinIO
- Доступ через clickhouse-backup контейнер
- Автоматическая ротация (7 дней)

## Резервное копирование

### Критические данные

- **Конфигурация:** В git репозитории
- **Бэкапы:** В S3/MinIO хранилище
- **Логи:** В `volumes/airflow/logs/`

### Восстановление системы

1. Развернуть инфраструктуру: `./deploy.sh`
2. Восстановить данные: `python scripts/clickhouse_backup_manager.py restore`
3. Проверить целостность: `python scripts/clickhouse_backup_manager.py health`

## Расширение функциональности

### Добавление новых типов бэкапов

1. Обновите `clickhouse_backup_manager.py`
2. Добавьте новые функции в DAG
3. Протестируйте изменения

### Интеграция с внешними системами

- **Уведомления:** Добавьте Slack/Email уведомления
- **Мониторинг:** Интеграция с Prometheus/Grafana
- **Аудит:** Логирование всех операций
