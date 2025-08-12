# 🚀 Быстрый старт ClickHouse EnergyHub

**Время выполнения: ~15 минут**

Этот туториал поможет вам быстро развернуть ClickHouse EnergyHub с нуля. Все команды пошаговые и готовы к копированию!

## 📋 Предварительные требования

Убедитесь, что у вас установлены:

- **Docker** (версия 20.10+)
- **Terraform** (версия 1.0+)
- **Python 3.8+**
- **Git**

### Проверка установки

```bash
# Проверяем Docker
docker --version

# Проверяем Terraform
terraform --version

# Проверяем Python
python3 --version

# Проверяем Git
git --version
```

## 🎯 Шаг 1: Клонирование репозитория

```bash
# Клонируем репозиторий
git clone https://github.com/principalwater/clickhouse-energyhub.git

# Переходим в директорию проекта
cd clickhouse-energyhub

# Проверяем содержимое
ls -la
```

## 🔧 Шаг 2: Настройка переменных

Создайте файл с переменными для Terraform:

```bash
# Переходим в директорию Terraform
cd infra/terraform

# Создаем файл с переменными (скопируйте пример)
cp terraform.tfvars.example terraform.tfvars
```

**🎯 Для быстрого старта (рекомендуется для тестирования):**
Файл `terraform.tfvars.example` уже содержит готовые значения и готов к использованию! Просто скопируйте его и запускайте `deploy.sh`.

**🔒 Для продакшена и безопасности:**
Рекомендуется заменить все пароли на уникальные и надежные значения перед развертыванием.

**Пример содержимого `terraform.tfvars` (готовые значения):**

```hcl
# Пароли для пользователей ClickHouse
super_user_password = "ClickHousePassword123!"
bi_user_password    = "BIPassword456!"

# Учетные данные для MinIO (S3)
minio_root_user     = "minioadmin"
minio_root_password = "MinIOPassword789!"

# Пользователь для SSH-доступа (локальный)
remote_ssh_user = "your_username"

# Пароль для суперпользователя в Postgres
pg_password = "PostgresPassword123!"

# Учетные данные для главного администратора в Metabase/Superset
sa_username = "admin"
sa_password = "AdminPassword456!"

# Секретный ключ для Superset (сгенерирован)
superset_secret_key = "d29b1a7d8e6f4c5a9b1d2e3f4g5h6i7j8k9l0m1n2o3p4q5r6s7t8u9v0w1x2y3z"

# Учетные данные для Kafka
kafka_admin_user            = "admin"
kafka_admin_password        = "KafkaPassword123!"
kafka_ssl_keystore_password = "KeystorePassword456!"

# Пароли для Airflow (включен по умолчанию)
deploy_airflow = true
airflow_postgres_password    = "AirflowPassword123!"
airflow_admin_password       = "AirflowAdmin456!"
airflow_fernet_key           = "BjijBVSuN3ik8oHEXMxd_D3TLTn2xsGVYcyFvILY9jk="
airflow_webserver_secret_key = "j3nkv2GAx2gl+bXsUtERWvPXeZOAs/i8lQglFwg2+F8="

# Telegram уведомления (опционально)
telegram_bot_token = "YOUR_BOT_TOKEN_HERE"  # Получите у @BotFather
telegram_chat_id   = "YOUR_CHAT_ID_HERE"   # Получите у @userinfobot
```

## 🚀 Шаг 3: Запуск развертывания

```bash
# Возвращаемся в корень проекта
cd ../../

# Делаем скрипт исполняемым
chmod +x deploy.sh

# Запускаем развертывание
./deploy.sh
```

**Что происходит во время развертывания:**

1. ✅ Проверка зависимостей (Docker, Terraform, Python)
2. 🔐 Загрузка учетных данных из `terraform.tfvars`
3. 🏗️ Инициализация Terraform
4. 📋 Планирование развертывания
5. 🚀 Создание инфраструктуры
6. 📦 Установка и настройка сервисов
7. 🔄 Копирование скриптов в контейнеры
8. 🔗 Создание подключений (ClickHouse, Kafka, Telegram)

**Внимание:** При запросе подтверждения введите `y` и нажмите Enter.

## ⏳ Шаг 4: Ожидание готовности

Развертывание занимает **10-15 минут**. Вы увидите прогресс в терминале.

**Признаки готовности:**
- ✅ Все контейнеры запущены
- 🟢 Статус "healthy" для основных сервисов
- 📊 Вывод информации о развернутых ресурсах

## 🎉 Шаг 5: Проверка работоспособности

### Проверка ClickHouse

```bash
# Подключение к ClickHouse
docker exec -it clickhouse-01 clickhouse-client --user admin --password 'your_secure_password'

# Проверка баз данных
SHOW DATABASES;

# Выход из клиента
EXIT;
```

### Проверка Airflow

```bash
# Проверка статуса Airflow
docker exec airflow-scheduler airflow dags list

# Проверка доступности веб-интерфейса
curl http://localhost:8080

# Проверка Telegram соединения (если настроено)
docker exec airflow-scheduler airflow connections list | grep telegram
```

**Airflow UI доступен по адресу:** http://localhost:8080

**Логин:** `airflow` / `airflow`

**💡 Telegram соединение:** Создается автоматически при деплое, если указаны переменные `telegram_bot_token` и `telegram_chat_id` в `terraform.tfvars`.

**💡 ClickHouse соединения:** Автоматически создаются в Metabase и Superset при деплое, используя учетные данные из `terraform.tfvars`.

## 🧪 Шаг 6: Тестирование dbt

```bash
# Переходим в директорию dbt
cd dbt/tools

# Делаем скрипты исполняемыми
chmod +x *.sh

# Настройка dbt
./dbt-manager.sh setup

# Проверка подключения
./dbt-manager.sh check

# Запуск моделей
./dbt-manager.sh run
```

## 📊 Шаг 7: Проверка данных

```bash
# Проверка таблиц в ClickHouse
docker exec clickhouse-01 clickhouse-client --user admin --password 'your_secure_password' --query "
SELECT 
    database,
    name,
    engine
FROM system.tables 
WHERE database IN ('raw', 'ods', 'dds', 'cdm')
ORDER BY database, name;
"
```

## 🌐 Доступ к сервисам

После успешного развертывания вам будут доступны:

| Сервис        | URL                    | Логин/Пароль                    |
|---------------|------------------------|--------------------------------|
| **Airflow**   | http://localhost:8080  | `airflow` / `airflow`          |
| **ClickHouse**| localhost:9000         | `admin` / `your_password`      |
| **Superset**  | http://localhost:8088  | `admin` / `admin`              |
| **Metabase**  | http://localhost:3000  | `admin@example.com` / `admin`  |
| **Portainer** | http://localhost:9443  | Создается при первом входе      |

## 🚨 Устранение неполадок

### Проблема: Docker не запущен
```bash
# Запуск Docker
sudo systemctl start docker
sudo systemctl enable docker
```

### Проблема: Порты заняты
```bash
# Проверка занятых портов
sudo netstat -tulpn | grep :8080

# Остановка конфликтующих сервисов
sudo systemctl stop conflicting-service
```

### Проблема: Недостаточно памяти
```bash
# Проверка доступной памяти
free -h

# Увеличение лимитов Docker (если нужно)
# В /etc/docker/daemon.json добавьте:
# {
#   "default-memory": "4g"
# }
```

### Проблема: Ошибки Terraform
```bash
# Очистка состояния Terraform
cd infra/terraform
terraform destroy -auto-approve
terraform init
./deploy.sh
```

## 📚 Следующие шаги

После успешного развертывания:

1. **📊 Настройте BI-инструменты** → [docs/BI_CLICKHOUSE_SETUP.md](docs/BI_CLICKHOUSE_SETUP.md)
2. **Изучите архитектуру** → [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
3. **Настройте мониторинг** → [docs/MONITORING.md](docs/MONITORING.md)
4. **Создайте свои dbt модели** → [docs/DBT_INTEGRATION.md](docs/DBT_INTEGRATION.md)
5. **Настройте CI/CD** → [docs/CI_CD.md](docs/CI_CD.md)

## 🆘 Получение помощи

- **Документация:** [docs/](docs/)
- **Issues:** [GitHub Issues](https://github.com/principalwater/clickhouse-energyhub/issues)
- **Discussions:** [GitHub Discussions](https://github.com/principalwater/clickhouse-energyhub/discussions)

## 🎯 Что вы получили

✅ **Полнофункциональный ClickHouse кластер** с 4 узлами  
✅ **Airflow** для оркестрации данных  
✅ **dbt** для трансформации данных  
✅ **Superset & Metabase** для визуализации (требуется ручная настройка подключений)  
✅ **Автоматические DAG'и** для обработки данных  
✅ **Систему дедупликации** каждые 5 минут  
✅ **Мониторинг и логирование**  

**Поздравляем! 🎉 Ваш ClickHouse EnergyHub успешно развернут и готов к работе!**
