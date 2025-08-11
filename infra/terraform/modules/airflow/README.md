# Terraform Module: Apache Airflow

## Архитектура

Этот модуль Terraform разворачивает полнофункциональную платформу Apache Airflow с интеграцией ClickHouse и Kafka для обработки энергетических данных. Архитектура включает:

- **PostgreSQL**: Хранилище метаданных Airflow (DAGs, задачи, выполнение)
- **Redis**: Брокер сообщений для Celery Executor
- **Airflow Webserver**: Веб-интерфейс для управления DAGs и мониторинга
- **Airflow Scheduler**: Планировщик задач и DAGs
- **Airflow Worker**: Исполнитель задач (Celery Worker)
- **Airflow Flower**: Мониторинг Celery кластера

### Интеграция с ClickHouse и Kafka

Модуль автоматически создает подключения к:
- **ClickHouse**: Для загрузки и обработки энергетических данных
- **Kafka**: Для чтения и записи потоковых данных

Все сервисы подключаются к соответствующим Docker-сетям для обеспечения коммуникации.

---

## Особенности

### Автоматическая инициализация
- Создание базы данных и пользователей PostgreSQL
- Инициализация метаданных Airflow
- Создание администратора Airflow
- Автоматическое создание подключений к ClickHouse и Kafka

### Готовые DAGs
- Пример DAG для интеграции ClickHouse с Kafka
- Автоматическое размещение в директории DAGs

### Масштабируемость
- Celery Executor для распределенного выполнения задач
- Возможность добавления дополнительных воркеров
- Мониторинг через Flower

---

## Входные переменные (Input Variables)

### Основные настройки
| Имя | Описание | Тип | По умолчанию |
| --- | --- | --- | --- |
| `deploy_airflow` | Развернуть Apache Airflow | `bool` | `false` |
| `airflow_version` | Версия Docker-образа Airflow | `string` | `"2.8.1"` |
| `airflow_postgres_version` | Версия PostgreSQL | `string` | `"16"` |
| `redis_version` | Версия Redis | `string` | `"7.2-alpine"` |

### Порты
| Имя | Описание | Тип | По умолчанию |
| --- | --- | --- | --- |
| `airflow_webserver_port` | Порт веб-интерфейса | `number` | `8080` |
| `airflow_flower_port` | Порт Flower мониторинга | `number` | `5555` |

### PostgreSQL
| Имя | Описание | Тип | По умолчанию |
| --- | --- | --- | --- |
| `airflow_postgres_user` | Пользователь PostgreSQL | `string` | `"airflow"` |
| `airflow_postgres_password` | Пароль PostgreSQL | `string` | **Обязательно** |
| `airflow_postgres_db` | База данных | `string` | `"airflow"` |
| `airflow_postgres_data_path` | Путь к данным | `string` | `"../../volumes/airflow/postgres"` |

### Airflow
| Имя | Описание | Тип | По умолчанию |
| --- | --- | --- | --- |
| `airflow_admin_user` | Администратор Airflow | `string` | `"admin"` |
| `airflow_admin_password` | Пароль администратора | `string` | **Обязательно** |
| `airflow_fernet_key` | Fernet ключ шифрования | `string` | **Обязательно** |
| `airflow_webserver_secret_key` | Секретный ключ веб-сервера | `string` | **Обязательно** |

### Пути к директориям
| Имя | Описание | Тип | По умолчанию |
| --- | --- | --- | --- |
| `airflow_dags_path` | DAG файлы | `string` | `"../../volumes/airflow/dags"` |
| `airflow_logs_path` | Логи | `string` | `"../../volumes/airflow/logs"` |
| `airflow_plugins_path` | Плагины | `string` | `"../../volumes/airflow/plugins"` |
| `airflow_config_path` | Конфигурация | `string` | `"../../volumes/airflow/config"` |

### Интеграция
| Имя | Описание | Тип | По умолчанию |
| --- | --- | --- | --- |
| `clickhouse_network_name` | Сеть ClickHouse | `string` | **Обязательно** |
| `clickhouse_bi_user` | BI пользователь ClickHouse | `string` | **Обязательно** |
| `clickhouse_bi_password` | Пароль BI пользователя | `string` | **Обязательно** |
| `kafka_network_name` | Сеть Kafka | `string` | **Обязательно** |
| `kafka_topic_1min` | Топик 1-минутных данных | `string` | **Обязательно** |
| `kafka_topic_5min` | Топик 5-минутных данных | `string` | **Обязательно** |

---

## Выходные значения (Outputs)

| Имя | Описание |
| --- | --- |
| `airflow_webserver_url` | URL веб-интерфейса Airflow |
| `airflow_flower_url` | URL мониторинга Flower |
| `airflow_network_name` | Имя Docker-сети Airflow |
| `airflow_postgres_container_name` | Имя контейнера PostgreSQL |
| `airflow_redis_container_name` | Имя контейнера Redis |
| `airflow_webserver_container_name` | Имя контейнера веб-сервера |
| `airflow_scheduler_container_name` | Имя контейнера планировщика |
| `airflow_worker_container_name` | Имя контейнера воркера |
| `airflow_flower_container_name` | Имя контейнера Flower |
| `airflow_admin_user` | Имя администратора |
| `airflow_postgres_connection_string` | Строка подключения к PostgreSQL |
| `airflow_redis_connection_string` | Строка подключения к Redis |
| `airflow_dags_path` | Путь к DAG файлам |
| `airflow_logs_path` | Путь к логам |
| `airflow_plugins_path` | Путь к плагинам |
| `airflow_config_path` | Путь к конфигурации |

---

## Доступ к сервисам

После успешного выполнения `terraform apply`:

- **Airflow Webserver:**
  - **URL:** `http://localhost:<airflow_webserver_port>` (по умолчанию `8080`)
  - **Вход:** Используйте учетные данные администратора из переменных

- **Flower (Celery мониторинг):**
  - **URL:** `http://localhost:<airflow_flower_port>` (по умолчанию `5555`)

---

## Интеграция с ClickHouse и Kafka

### Автоматически создаваемые подключения

Модуль создает следующие подключения в Airflow:

1. **`clickhouse_default`**
   - Тип: `clickhouse`
   - Хост: `clickhouse-1`
   - Порт: `9000`
   - Пользователь: из переменной `clickhouse_bi_user`
   - Пароль: из переменной `clickhouse_bi_password`

2. **`kafka_default`**
   - Тип: `kafka`
   - Хост: `kafka`
   - Порт: `9092`
   - Протокол: `PLAINTEXT`

### Использование в DAGs

```python
from airflow.providers.clickhouse.operators.clickhouse import ClickHouseOperator
from airflow.providers.kafka.producer import KafkaProducerOperator

# Оператор ClickHouse
clickhouse_task = ClickHouseOperator(
    task_id='load_data_to_clickhouse',
    clickhouse_conn_id='clickhouse_default',
    sql='INSERT INTO energy_data VALUES ({{ params.value }})'
)

# Оператор Kafka
kafka_task = KafkaProducerOperator(
    task_id='send_to_kafka',
    kafka_conn_id='kafka_default',
    topic='energy_data_1min',
    value='{{ params.data }}'
)
```

---

## Устранение неполадок (Troubleshooting)

### Общие проблемы

- **Сервис не запускается:**
  - Проверьте, что все обязательные переменные заданы
  - Убедитесь, что порты не заняты другими сервисами
  - Проверьте логи: `docker logs <container_name>`

- **Ошибка подключения к ClickHouse/Kafka:**
  - Убедитесь, что соответствующие модули развернуты
  - Проверьте правильность имен сетей
  - Убедитесь, что сервисы доступны по указанным хостам

- **Ошибка инициализации Airflow:**
  - Проверьте готовность PostgreSQL и Redis
  - Убедитесь, что все пароли корректны
  - Проверьте права доступа к директориям

### Полезные команды

```bash
# Проверка статуса контейнеров
docker ps -a | grep airflow

# Просмотр логов
docker logs airflow_webserver
docker logs airflow_scheduler
docker logs airflow_worker

# Проверка подключений в Airflow
docker exec airflow_webserver airflow connections list

# Перезапуск сервиса
docker restart airflow_webserver
```

---

## Сценарии использования

### Базовое развертывание
```hcl
module "airflow" {
  source = "./modules/airflow"
  
  deploy_airflow = true
  
  # Обязательные параметры
  airflow_admin_password = "your_admin_password"
  airflow_fernet_key = "your_fernet_key"
  airflow_webserver_secret_key = "your_secret_key"
  airflow_postgres_password = "your_postgres_password"
  
  # Интеграция
  clickhouse_network_name = module.clickhouse_cluster.network_name
  clickhouse_bi_user = var.bi_user_name
  clickhouse_bi_password = var.bi_user_password
  
  kafka_network_name = module.kafka.network_name
  kafka_topic_1min = var.topic_1min
  kafka_topic_5min = var.topic_5min
}
```

### Кастомизация портов
```hcl
module "airflow" {
  source = "./modules/airflow"
  
  deploy_airflow = true
  airflow_webserver_port = 9090
  airflow_flower_port = 6666
  
  # ... остальные параметры
}
```

---

## Полезные ссылки

- [Apache Airflow](https://airflow.apache.org/)
- [Airflow Providers](https://airflow.apache.org/docs/apache-airflow-providers/)
- [ClickHouse Provider](https://airflow.apache.org/docs/apache-airflow-providers-clickhouse/)
- [Kafka Provider](https://airflow.apache.org/docs/apache-airflow-providers-apache-kafka/)
- [Celery Executor](https://airflow.apache.org/docs/apache-airflow/stable/executor/celery.html)
- [Terraform](https://www.terraform.io/)
