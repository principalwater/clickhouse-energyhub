# Туториал: Развертывание EnergyHub за 15 минут

Это пошаговое руководство поможет вам быстро развернуть весь проект EnergyHub на вашем локальном компьютере с полной интеграцией ClickHouse, Kafka, PostgreSQL, Apache Airflow 3.0.4 и BI-инструментов.

## Шаг 0: Предварительные требования

Убедитесь, что у вас установлены следующие инструменты:
- [Git](https://git-scm.com/)
- [Docker и Docker Compose](https://www.docker.com/products/docker-desktop/) (Docker должен быть запущен)
- [Terraform](https://www.terraform.io/downloads.html) (версия 1.0.0 или выше)

## Шаг 1: Клонирование репозитория

Откройте терминал и выполните следующую команду:
```bash
git clone https://github.com/principalwater/clickhouse-energyhub.git
cd clickhouse-energyhub
```
*(Замените `your-username` на ваш реальный username на GitHub)*

## Шаг 2: Настройка конфигурации

Вся конфигурация проекта управляется из одного места. Мы предоставили файл-пример, который нужно скопировать и заполнить.

1.  **Перейдите в директорию Terraform:**
    ```bash
    cd infra/terraform
    ```

2.  **Скопируйте файл-пример:**
    ```bash
    cp terraform.tfvars.example terraform.tfvars
    ```

3.  **Отредактируйте `terraform.tfvars`:**
    Откройте только что созданный файл `terraform.tfvars` в вашем любимом текстовом редакторе. Вам **обязательно** нужно заменить все плейсхолдеры `YOUR_..._PASSWORD` и `YOUR_..._KEY` на ваши собственные надежные пароли и ключи.

    **Пример заполнения:**
    ```hcl
    # ...
    super_user_password = "MySecureClickHousePassword123!"
    # ...
    pg_password         = "MySecurePostgresPassword456!"
    # ...
    superset_secret_key = "d29b1a7d8e6f4c5a9b1d2e3f4g5h6i7j" # Сгенерируйте свой ключ
    # ...
    ```
    > **Важно:** Для `superset_secret_key` сгенерируйте уникальную строку, например, с помощью команды `openssl rand -base64 32`.

## Шаг 3: Настройка переменных для всех модулей

В файле `terraform.tfvars` убедитесь, что заполнены все необходимые переменные для модулей PostgreSQL, Kafka, Monitoring и Airflow:

### Основные конфигурации

```hcl
# PostgreSQL Configuration (централизованная БД)
pg_password = "YOUR_SECURE_POSTGRES_PASSWORD"

# Kafka Configuration
kafka_version               = "7.4.0"
kafka_admin_user           = "admin"
kafka_admin_password       = "YOUR_KAFKA_ADMIN_PASSWORD"
kafka_ssl_keystore_password = "YOUR_KEYSTORE_PASSWORD"
topic_1min                 = "energy_data_1min"
topic_5min                 = "energy_data_5min"

# Monitoring Configuration  
portainer_version    = "2.19.4"
portainer_https_port = 9443
portainer_agent_port = 9000
```

### Airflow 3.0.4 Configuration (рекомендуется включить)

```hcl
# Apache Airflow 3.0.4
deploy_airflow = true
airflow_version = "3.0.4"

# Пароли для сервисов (используют PostgreSQL из модуля postgres)
airflow_postgres_user     = "airflow"
airflow_postgres_password = "YOUR_AIRFLOW_POSTGRES_PASSWORD"
airflow_postgres_db       = "airflow"

# Администратор Airflow
airflow_admin_user     = "admin"
airflow_admin_password = "YOUR_AIRFLOW_ADMIN_PASSWORD"

# Ключи шифрования (сгенерируйте свои!)
airflow_fernet_key           = "YOUR_FERNET_KEY_32_CHARS_BASE64"
airflow_webserver_secret_key = "YOUR_AIRFLOW_SECRET_KEY"

# BI-инструменты (используют PostgreSQL из модуля postgres)
metabase_pg_user     = "metabase"
metabase_pg_password = "YOUR_METABASE_PASSWORD"
metabase_pg_db       = "metabaseappdb"

superset_pg_user     = "superset"
superset_pg_password = "YOUR_SUPERSET_PASSWORD"
superset_pg_db       = "superset"
```

### Генерация ключей

**Важные команды для генерации безопасных ключей:**

```bash
# Fernet ключ для Airflow (32 символа base64)
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"

# Секретный ключ для Airflow веб-сервера
openssl rand -base64 32

# Секретный ключ для Superset
openssl rand -base64 32
```

**Важно:** 
- SSL-сертификаты для Kafka будут сгенерированы автоматически во время выполнения `terraform apply`.
- PostgreSQL создает централизованную базу данных для всех сервисов с отдельными пользователями.
- Airflow 3.0.4 использует новую архитектуру с улучшенными health checks и автоматической интеграцией с ClickHouse и Kafka.

## Шаг 4: Развертывание инфраструктуры

Теперь, когда конфигурация готова, можно запускать Terraform.

1.  **Инициализация:**
    Выполните эту команду, чтобы Terraform скачал необходимые провайдеры.
    ```bash
    terraform init
    ```

2.  **Проверка плана (опционально):**
    Просмотрите, что будет создано:
    ```bash
    terraform plan
    ```

3.  **Развертывание:**
    Эта команда создаст все Docker-контейнеры и настроит их. По умолчанию используется режим `local_storage`, который идеально подходит для локального запуска на одной машине.
    ```bash
    terraform apply -auto-approve
    ```
    
    **Ожидаемое время выполнения:** 15-20 минут
    
    **Что происходит во время развертывания:**
    - Скачивание Docker образов (ClickHouse, Kafka, PostgreSQL, Airflow 3.0.4, и др.)
    - Создание Docker сетей и томов
    - Инициализация PostgreSQL и создание пользователей для всех сервисов
    - Генерация SSL-сертификатов для Kafka
    - Инициализация Apache Airflow 3.0.4 с миграцией базы данных
    - Создание подключений между всеми сервисами
    - Настройка health checks для всех контейнеров

## Шаг 5: Доступ к сервисам

После завершения `terraform apply` ваша платформа готова к работе!

### Веб-интерфейсы

| Сервис | URL | Логин | Пароль |
|---------|-----|-------|---------|
| **Apache Airflow** | http://localhost:8080 | `admin` | из `terraform.tfvars` |
| **Airflow Flower** | http://localhost:5555 | — | — |
| **Metabase** | http://localhost:3000 | Первичная настройка | При первом входе |
| **Apache Superset** | http://localhost:8088 | `admin` | из `terraform.tfvars` |
| **Portainer** | https://localhost:9443 | `admin` | Создается при первом входе |

### Базы данных и API

| Сервис | Эндпоинт | Описание |
|---------|----------|----------|
| **ClickHouse HTTP** | http://localhost:8123 | Запросы к ClickHouse |
| **ClickHouse TCP** | localhost:9000 | Нативный протокол ClickHouse |
| **Kafka External** | localhost:9093 | Внешние клиенты (SASL_SSL) |
| **PostgreSQL** | localhost:5432 | Централизованная БД |
| **Redis** | localhost:6379 | Celery брокер для Airflow |

### Первичная настройка

1. **Airflow**: Войдите с учетными данными из `terraform.tfvars`. Готовый пример DAG `energy_data_pipeline` будет доступен сразу.

2. **Metabase**: При первом входе пройдите мастер первичной настройки:
   - База данных: PostgreSQL
   - Хост: `postgres`
   - Порт: `5432`
   - Имя БД: `metabaseappdb`
   - Пользователь: `metabase`
   - Пароль: из `terraform.tfvars`

3. **Superset**: Войдите с учетными данными администратора из `terraform.tfvars`.

4. **Portainer**: При первом входе создайте пароль администратора.

## Шаг 6: Запуск генерации данных

Чтобы наполнить Kafka данными для анализа, вы можете запустить Python-скрипты. Откройте новый терминал в корне проекта `clickhouse-energyhub`.

1.  **Установите зависимости:**
    ```bash
    pip install -r scripts/kafka_producer/requirements.txt
    ```

2.  **Запустите генераторы:**
    *   Для данных о торгах на бирже (1-минутные):
        ```bash
        python scripts/kafka_producer/generate_market_data.py
        ```
    *   Для данных о речном стоке (5-минутные):
        ```bash
        python scripts/kafka_producer/generate_river_flow.py
        ```

## Шаг 7: Работа с Apache Airflow

### Готовые DAG'и

Airflow включает готовый пример DAG `energy_data_pipeline` для демонстрации интеграции:

1. Откройте http://localhost:8080
2. Войдите с учетными данными администратора
3. В разделе "DAGs" найдите `energy_data_pipeline`
4. Включите DAG переключателем
5. Запустите вручную кнопкой "Trigger DAG"

### Подключения в Airflow

Автоматически созданы подключения:
- **`clickhouse_default`**: Подключение к ClickHouse
- **`kafka_default`**: Подключение к Kafka

Проверить можно в меню Admin → Connections.

## Шаг 8: Проверка работоспособности

### Быстрая диагностика

```bash
# Проверка статуса всех контейнеров
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(airflow|postgres|kafka|clickhouse|redis)"

# Проверка health checks
curl http://localhost:8080/health          # Airflow
curl http://localhost:8123/ping            # ClickHouse
curl http://localhost:3000/api/health      # Metabase

# Проверка логов (при проблемах)
docker logs airflow-api-server
docker logs postgres
docker logs kafka
```

### Ожидаемые результаты

✅ **Все контейнеры должны показывать статус "Up" или "healthy"**  
✅ **Веб-интерфейсы должны быть доступны**  
✅ **Health checks должны возвращать статус 200 OK**  

## 🚀 Готово!

Поздравляем! Вы успешно развернули всю платформу EnergyHub с современным Apache Airflow 3.0.4, централизованной PostgreSQL и полной интеграцией всех компонентов.

### Что у вас теперь есть:

✅ **Кластер ClickHouse** для аналитики больших данных  
✅ **Apache Kafka** для потоковой передачи данных  
✅ **PostgreSQL** как централизованная база данных  
✅ **Apache Airflow 3.0.4** для оркестрации ETL/ELT процессов  
✅ **Metabase & Superset** для визуализации и BI  
✅ **Portainer** для мониторинга Docker инфраструктуры  
✅ **Готовые интеграции** между всеми компонентами  

### Продвинутая конфигурация

Проект очень гибкий. Вы можете:
- **Отключать отдельные сервисы:** Установите `deploy_airflow = false` или `deploy_metabase = false` в `terraform.tfvars`.
- **Использовать другие режимы хранения:** Измените `storage_type` на `s3_ssd` или режим с удаленными бэкапами.
- **Масштабировать Airflow:** Добавьте дополнительные воркеры через настройки Celery.
- **Настроить ACL в Kafka:** Включите `enable_kafka_acl = true` для продвинутой авторизации.

### Дальнейшее изучение

Для детального описания всех возможностей каждого компонента, обратитесь к README соответствующего модуля:

- [**PostgreSQL**](./infra/terraform/modules/postgres/README.md) — Централизованная база данных
- [**Apache Airflow 3.0.4**](./infra/terraform/modules/airflow/README.md) — Оркестрация задач  
- [**Кластер ClickHouse**](./infra/terraform/modules/clickhouse-cluster/README.md) — Аналитическая база данных
- [**Apache Kafka**](./infra/terraform/modules/kafka/README.md) — Потоковая обработка данных
- [**Инфраструктура BI**](./infra/terraform/modules/bi-infra/README.md) — Визуализация данных
- [**Мониторинг (Portainer)**](./infra/terraform/modules/monitoring/README.md) — Управление контейнерами

---

## 🔧 Устранение неполадок

### Airflow контейнеры показывают "unhealthy"

```bash
# Отключить проблемные healthcheck'и (если нужно)
# В terraform.tfvars добавить:
# disable_healthchecks = true
# Затем выполнить:
terraform apply -target="module.airflow"
```

### PostgreSQL connection errors

```bash
# Проверить готовность PostgreSQL
docker exec postgres pg_isready -U postgres

# Проверить пользователей
docker exec postgres psql -U postgres -c "\du"
```

### Kafka SSL errors

```bash
# Проверить сертификаты
ls -la secrets/kafka/
docker logs kafka
```

Удачи в изучении современной аналитической платформы! 🚀
