# Terraform Module: Apache Airflow 3.0.4

Этот модуль Terraform разворачивает современную полнофункциональную платформу Apache Airflow 3.0.4 с интеграцией ClickHouse и Kafka для обработки энергетических данных. Архитектура основана на официальной документации Docker Compose и полностью совместима с последними обновлениями Airflow.

## Архитектура

Модуль создает следующие компоненты в соответствии с архитектурой Airflow 3.0.4:

### Основные сервисы
- **airflow-api-server**: Веб-интерфейс и API (порт 8080)
- **airflow-scheduler**: Планировщик задач и DAGs
- **airflow-dag-processor**: Обработчик DAG файлов (новое в 3.0)
- **airflow-worker**: Исполнитель задач (Celery Worker)
- **airflow-triggerer**: Для отложенных задач
- **redis**: Брокер сообщений для CeleryExecutor
- **postgres**: Внешняя база данных метаданных (из модуля postgres)

### Дополнительные сервисы
- **airflow-flower**: Мониторинг Celery кластера (опционально)

### Автоматизация
- **airflow-init**: Одноразовая инициализация базы данных
- **Создание директорий**: Автоматическое создание необходимых папок
- **Подключения**: Автоматическая настройка соединений с ClickHouse и Kafka
- **Sample DAG**: Пример DAG для интеграции энергетических данных

---

## Ключевые особенности Airflow 3.0.4

### Новые возможности
✅ **Standalone DAG Processor**: Отдельный процесс для обработки DAG'ов  
✅ **Улучшенные Health Checks**: Встроенные проверки состояния компонентов  
✅ **Auth Manager**: Новая система аутентификации и авторизации  
✅ **Database Access Isolation**: Изоляция доступа к базе данных  
✅ **Internal API**: Внутренний API для коммуникации между компонентами  

### Безопасность и стабильность
✅ **Автоматическая инициализация**: `_AIRFLOW_DB_MIGRATE` и `_AIRFLOW_WWW_USER_CREATE`  
✅ **Корректные права пользователей**: PostgreSQL с полными привилегиями  
✅ **Умные healthcheck'и**: Fallback проверки без использования `pgrep`  
✅ **Возможность отключения healthcheck'ов**: Для проблемных случаев  

---

## Входные переменные (Input Variables)

### Основные настройки
| Имя                    | Описание                                    | Тип      | По умолчанию |
|------------------------|---------------------------------------------|-----------|--------------|
| `deploy_airflow`       | Развернуть Apache Airflow                  | `bool`    | `false`      |
| `airflow_version`      | Версия Docker-образа Apache Airflow        | `string`  | `"3.0.4"`    |
| `redis_version`        | Версия Redis для Celery брокера            | `string`  | `"latest"`   |
| `enable_flower`        | Включить Flower для мониторинга Celery     | `bool`    | `false`      |
| `disable_healthchecks` | Отключить healthcheck'и для worker/triggerer| `bool`    | `false`      |

### Порты
| Имя                    | Описание                | Тип      | По умолчанию |
|------------------------|-------------------------|-----------|--------------|
| `airflow_webserver_port`| Порт веб-интерфейса/API | `number`  | `8080`       |
| `airflow_flower_port`  | Порт Flower мониторинга | `number`  | `5555`       |

### PostgreSQL (внешняя база данных)
| Имя                            | Описание                        | Тип      | Обязательно |
|--------------------------------|---------------------------------|-----------|-------------|
| `airflow_postgres_connection_string`| Строка подключения к PostgreSQL| `string`  | ✅           |
| `postgres_network_name`        | Имя Docker-сети PostgreSQL     | `string`  | ✅           |

### Аутентификация Airflow
| Имя                        | Описание                    | Тип      | По умолчанию |
|----------------------------|-----------------------------|-----------|--------------|
| `airflow_admin_user`       | Администратор Airflow       | `string`  | `"admin"`    |
| `airflow_admin_password`   | Пароль администратора       | `string`  | **Обязательно** |
| `airflow_fernet_key`       | Fernet ключ шифрования      | `string`  | **Обязательно** |
| `airflow_webserver_secret_key`| Секретный ключ веб-сервера| `string`  | **Обязательно** |

### Пути к директориям
| Имя                    | Описание                | Тип      | По умолчанию                    |
|------------------------|-------------------------|-----------|--------------------------------|
| `airflow_dags_path`    | Путь к DAG файлам       | `string`  | `"../../volumes/airflow/dags"`  |
| `airflow_logs_path`    | Путь к логам            | `string`  | `"../../volumes/airflow/logs"`  |
| `airflow_plugins_path` | Путь к плагинам         | `string`  | `"../../volumes/airflow/plugins"`|
| `airflow_config_path`  | Путь к конфигурации     | `string`  | `"../../volumes/airflow/config"` |
| `airflow_redis_data_path`| Путь к данным Redis    | `string`  | `"../../volumes/airflow/redis"`  |

### Интеграция с внешними сервисами
| Имя                    | Описание                | Тип      | Обязательно |
|------------------------|-------------------------|-----------|-------------|
| `clickhouse_network_name`| Имя Docker-сети ClickHouse| `string` | ✅           |
| `clickhouse_bi_user`   | BI пользователь ClickHouse| `string` | ✅           |
| `clickhouse_bi_password`| Пароль BI пользователя | `string` | ✅           |
| `kafka_network_name`   | Имя Docker-сети Kafka  | `string` | ✅           |
| `kafka_topic_1min`     | Топик 1-минутных данных| `string` | ✅           |
| `kafka_topic_5min`     | Топик 5-минутных данных| `string` | ✅           |

---

## Выходные значения (Outputs)

### Доступ к сервисам
| Имя | Описание |
| --- | --- |
| `airflow_webserver_url` | URL веб-интерфейса Airflow |
| `airflow_flower_url` | URL мониторинга Flower (если включен) |

### Информация о контейнерах
| Имя | Описание |
| --- | --- |
| `airflow_api_server_container_name` | Имя контейнера API сервера |
| `airflow_scheduler_container_name` | Имя контейнера планировщика |
| `airflow_worker_container_name` | Имя контейнера воркера |
| `airflow_dag_processor_container_name` | Имя контейнера DAG процессора |
| `airflow_triggerer_container_name` | Имя контейнера triggerer |
| `airflow_flower_container_name` | Имя контейнера Flower |
| `airflow_redis_container_name` | Имя контейнера Redis |

### Сетевая информация
| Имя | Описание |
| --- | --- |
| `airflow_network_name` | Имя Docker-сети Airflow |
| `airflow_redis_connection_string` | Строка подключения к Redis |

### Пути и конфигурация
| Имя | Описание |
| --- | --- |
| `airflow_admin_user` | Имя администратора |
| `airflow_dags_path` | Путь к DAG файлам |
| `airflow_logs_path` | Путь к логам |
| `airflow_plugins_path` | Путь к плагинам |
| `airflow_config_path` | Путь к конфигурации |

---

## Доступ к сервисам

После успешного выполнения `terraform apply`:

### Airflow API Server (Webserver)
- **URL**: `http://localhost:8080` (по умолчанию)
- **Логин**: Значение переменной `airflow_admin_user`
- **Пароль**: Значение переменной `airflow_admin_password`

### Airflow Flower (если включен)
- **URL**: `http://localhost:5555` (по умолчанию)
- **Функции**: Мониторинг Celery воркеров, задач, очередей

### Health Checks
- **Scheduler**: `http://localhost:8974/health`
- **API Server**: `http://localhost:8080/api/v2/version`

---

## Автоматически создаваемые подключения

Модуль автоматически создает следующие подключения в Airflow:

### 1. ClickHouse Connection (`clickhouse_default`)
```python
conn_id='clickhouse_default'
conn_type='clickhouse'
host='clickhouse-01'
port=9000
login=var.clickhouse_bi_user
password=var.clickhouse_bi_password
```

### 2. Kafka Connection (`kafka_default`)
```python
conn_id='kafka_default'
conn_type='kafka'
host='kafka'
port=9092
extra='{"security.protocol": "PLAINTEXT"}'
```

---

## Интеграция в DAGs

### ClickHouse Integration
```python
from airflow.providers.clickhouse.operators.clickhouse import ClickHouseOperator

clickhouse_task = ClickHouseOperator(
    task_id='load_energy_data',
    clickhouse_conn_id='clickhouse_default',
    sql="""
        INSERT INTO energy_hub.energy_data 
        SELECT * FROM input('timestamp DateTime, value Float64') 
        FORMAT CSVWithNames
    """,
    parameters={'batch_size': 1000}
)
```

### Kafka Integration
```python
from airflow.providers.kafka.operators.produce import ProduceToTopicOperator

kafka_producer = ProduceToTopicOperator(
    task_id='send_to_kafka',
    kafka_conn_id='kafka_default',
    topic='energy_data_1min',
    producer_config={'acks': 'all'},
    key='energy_sensor_{{ ds }}',
    value='{{ ti.xcom_pull(task_ids="previous_task") }}'
)
```

---

## Sample DAG

Модуль автоматически создает пример DAG (`energy_data_pipeline.py`):

```python
"""
Example Energy Data Pipeline DAG for ClickHouse and Kafka Integration
Demonstrates data processing pipeline for energy consumption data
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.clickhouse.operators.clickhouse import ClickHouseOperator

default_args = {
    'owner': 'energy-team',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'energy_data_pipeline',
    default_args=default_args,
    description='Energy Data Processing Pipeline',
    schedule='@hourly',
    catchup=False,
    tags=['energy', 'clickhouse', 'kafka'],
)

def process_energy_data(**context):
    """Process energy consumption data"""
    # Пример обработки данных
    return {'processed_records': 1000, 'timestamp': context['ds']}

process_task = PythonOperator(
    task_id='process_energy_data',
    python_callable=process_energy_data,
    dag=dag,
)

load_to_clickhouse = ClickHouseOperator(
    task_id='load_to_clickhouse',
    clickhouse_conn_id='clickhouse_default',
    sql="""
        INSERT INTO energy_hub.hourly_consumption 
        VALUES (now(), {{ ti.xcom_pull(task_ids='process_energy_data')['processed_records'] }})
    """,
    dag=dag,
)

process_task >> load_to_clickhouse
```

---

## Сценарии использования

### Базовое развертывание
```hcl
module "airflow" {
  source = "./modules/airflow"
  
  # Основные настройки
  deploy_airflow = true
  airflow_version = "3.0.4"
  enable_flower = false
  
  # Обязательные параметры безопасности
  airflow_admin_user = "admin"
  airflow_admin_password = "secure_admin_password"
  airflow_fernet_key = "your_32_character_fernet_key_here"
  airflow_webserver_secret_key = "your_secret_key_here"
  
  # PostgreSQL (из модуля postgres)
  airflow_postgres_connection_string = module.postgres.airflow_db_connection_string
  postgres_network_name = module.postgres.postgres_network_name
  
  # Интеграция с ClickHouse
  clickhouse_network_name = module.clickhouse_cluster.network_name
  clickhouse_bi_user = var.bi_user_name
  clickhouse_bi_password = var.bi_user_password
  
  # Интеграция с Kafka
  kafka_network_name = module.kafka.network_name
  kafka_topic_1min = var.topic_1min
  kafka_topic_5min = var.topic_5min
  
  depends_on = [module.clickhouse_cluster, module.kafka, module.postgres]
}
```

### Развертывание с Flower мониторингом
```hcl
module "airflow" {
  source = "./modules/airflow"
  
  deploy_airflow = true
  enable_flower = true  # Включить мониторинг Celery
  
  # Кастомные порты
  airflow_webserver_port = 9090
  airflow_flower_port = 6666
  
  # ... остальные параметры
}
```

### Production конфигурация
```hcl
module "airflow" {
  source = "./modules/airflow"
  
  deploy_airflow = true
  enable_flower = true
  disable_healthchecks = false  # Оставить healthcheck'и
  
  # Кастомные пути для production
  airflow_dags_path = "/opt/airflow/production/dags"
  airflow_logs_path = "/opt/airflow/production/logs"
  airflow_plugins_path = "/opt/airflow/production/plugins"
  airflow_config_path = "/opt/airflow/production/config"
  
  # ... остальные параметры
}
```

---

## Устранение неполадок (Troubleshooting)

### Проблемы с инициализацией

#### 1. **Permission denied for schema public**
```bash
# Проверить права PostgreSQL пользователя
docker exec postgres psql -U postgres -c "\du airflow"

# Предоставить права (выполняется автоматически)
docker exec postgres psql -U postgres -d airflow -c "
  GRANT ALL PRIVILEGES ON SCHEMA public TO airflow;
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO airflow;
"
```

#### 2. **"No such container: airflow_init"**
Это нормально! Контейнер `airflow_init` удаляется после успешной инициализации.

#### 3. **Multiple database migrations**
Используется `null_resource` для одноразовой инициализации, что предотвращает конфликты.

### Проблемы с healthcheck'ами

#### 1. **Container показывает "unhealthy"**
```bash
# Проверить статус healthcheck'ов
docker inspect airflow-worker | grep -A 10 "Health"

# При необходимости отключить healthcheck'и
# В main.tf установить: disable_healthchecks = true
```

#### 2. **"Permission denied" в healthcheck'ах**
Модуль использует Python проверки вместо `pgrep` для избежания проблем с правами.

### Диагностические команды

```bash
# Статус всех контейнеров Airflow
docker ps --format "table {{.Names}}\t{{.Status}}" | grep airflow

# Логи конкретного сервиса
docker logs airflow-api-server
docker logs airflow-scheduler
docker logs airflow-worker

# Проверить подключения в Airflow
docker exec airflow-api-server airflow connections list

# Проверить DAGs
docker exec airflow-api-server airflow dags list

# Проверить состояние базы данных
docker exec postgres psql -U postgres -d airflow -c "\dt" | head -10

# Проверить Redis
docker exec redis redis-cli ping

# Health checks
curl http://localhost:8080/health
curl http://localhost:8974/health  # Scheduler health server
```

### Полезные команды для разработки

```bash
# Перезапуск отдельного сервиса
docker restart airflow-scheduler

# Выполнить DAG вручную
docker exec airflow-api-server airflow dags trigger energy_data_pipeline

# Проверить очереди Celery (если включен Flower)
curl http://localhost:5555/api/queues

# Просмотр переменных окружения
docker exec airflow-worker env | grep AIRFLOW
```

---

## Интеграция с другими модулями

### Модуль postgres
```hcl
module "postgres" {
  source = "./modules/postgres"
  
  enable_postgres = true
  enable_airflow = true  # Включить поддержку Airflow
  
  airflow_pg_user = "airflow"
  airflow_pg_password = var.airflow_postgres_password
  airflow_pg_db = "airflow"
}

module "airflow" {
  source = "./modules/airflow"
  
  # Использовать PostgreSQL из модуля postgres
  airflow_postgres_connection_string = module.postgres.airflow_db_connection_string
  postgres_network_name = module.postgres.postgres_network_name
  
  depends_on = [module.postgres]
}
```

### Модуль clickhouse-cluster
```hcl
module "airflow" {
  source = "./modules/airflow"
  
  # Интеграция с ClickHouse
  clickhouse_network_name = module.clickhouse_cluster.network_name
  clickhouse_bi_user = var.bi_user_name
  clickhouse_bi_password = var.bi_user_password
  
  depends_on = [module.clickhouse_cluster]
}
```

### Модуль kafka
```hcl
module "airflow" {
  source = "./modules/airflow"
  
  # Интеграция с Kafka
  kafka_network_name = module.kafka.network_name
  kafka_topic_1min = var.topic_1min
  kafka_topic_5min = var.topic_5min
  
  depends_on = [module.kafka]
}
```

---

## Миграция с Airflow 2.x

### Основные изменения в 3.0.4
1. **DAG Processor**: Теперь отдельный сервис
2. **Auth Manager**: Новая система аутентификации
3. **Internal API**: Новая архитектура коммуникации
4. **Health Checks**: Улучшенные проверки состояния

### Обновление переменных
```hcl
# Старая конфигурация (2.x)
airflow_version = "2.8.1"

# Новая конфигурация (3.0.4)
airflow_version = "3.0.4"
disable_healthchecks = false  # Новая переменная
```

---

## Полезные ссылки

- [Apache Airflow 3.0.4](https://airflow.apache.org/docs/apache-airflow/3.0.4/)
- [Airflow Docker Compose](https://airflow.apache.org/docs/apache-airflow/3.0.4/howto/docker-compose/index.html)
- [Airflow Providers](https://airflow.apache.org/docs/apache-airflow-providers/)
- [ClickHouse Provider](https://airflow.apache.org/docs/apache-airflow-providers-clickhouse/)
- [Kafka Provider](https://airflow.apache.org/docs/apache-airflow-providers-apache-kafka/)
- [CeleryExecutor](https://airflow.apache.org/docs/apache-airflow/stable/executor/celery.html)
- [Airflow Health Checks](https://airflow.apache.org/docs/apache-airflow/stable/administration-and-deployment/logging-monitoring/check-health.html)
- [Terraform Docker Provider](https://registry.terraform.io/providers/kreuzwerker/docker/latest)