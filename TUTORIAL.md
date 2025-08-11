# Туториал: Развертывание EnergyHub за 15 минут

Это пошаговое руководство поможет вам быстро развернуть весь проект EnergyHub на вашем локальном компьютере.

## Шаг 0: Предварительные требования

Убедитесь, что у вас установлены следующие инструменты:
- [Git](https://git-scm.com/)
- [Docker и Docker Compose](https://www.docker.com/products/docker-desktop/) (Docker должен быть запущен)
- [Terraform](https://www.terraform.io/downloads.html) (версия 1.0.0 или выше)

## Шаг 1: Клонирование репозитория

Откройте терминал и выполните следующую команду:
```bash
git clone https://github.com/your-username/clickhouse-energyhub.git
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

## Шаг 3: Настройка переменных для новых модулей

В файле `terraform.tfvars` убедитесь, что заполнены все необходимые переменные для модулей Kafka и Monitoring:

```hcl
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

**Важно:** SSL-сертификаты для Kafka будут сгенерированы автоматически во время выполнения `terraform apply` с использованием скрипта `scripts/generate_certs.sh`. Убедитесь, что пароль `kafka_ssl_keystore_password` надежный и соответствует вашим требованиям безопасности.

## Шаг 4: Развертывание инфраструктуры

Теперь, когда конфигурация готова, можно запускать Terraform.

1.  **Инициализация:**
    Выполните эту команду, чтобы Terraform скачал необходимые провайдеры.
    ```bash
    terraform init
    ```

2.  **Развертывание:**
    Эта команда создаст все Docker-контейнеры и настроит их. По умолчанию используется режим `local_storage`, который идеально подходит для локального запуска на одной машине.
    ```bash
    terraform apply -auto-approve
    ```
    Процесс займет несколько минут, так как будут скачиваться образы Docker и инициализироваться базы данных.

## Шаг 5: Доступ к сервисам

После завершения `terraform apply` ваша платформа готова к работе!

| Сервис | URL |
| --- | --- |
| **Portainer**| https://localhost:9443 |
| **Metabase** | http://localhost:3000 |
| **Superset** | http://localhost:8088 |
| **Kafka** | `localhost:9092` (адрес брокера) |

Для входа в Metabase и Superset используйте учетные данные администратора, которые вы указали в `terraform.tfvars` (`sa_username` и `sa_password`).

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

## 🚀 Готово!

Поздравляем! Вы успешно развернули всю платформу EnergyHub. Теперь вы можете заходить в Metabase или Superset, подключаться к ClickHouse и анализировать поступающие из Kafka данные.

### Продвинутая конфигурация

Проект очень гибкий. Вы можете:
- **Отключать BI-инструменты:** Установите `deploy_metabase = false` в `terraform.tfvars`.
- **Использовать другие режимы хранения:** Измените `storage_type` на `s3_ssd` или режим с удаленными бэкапами.

Для детального описания всех возможностей каждого компонента, пожалуйста, обратитесь к `README` соответствующего модуля:
- [**Кластер ClickHouse**](./infra/terraform/modules/clickhouse-cluster/README.md)
- [**Инфраструктура BI**](./infra/terraform/modules/bi-infra/README.md)
- [**Apache Kafka**](./infra/terraform/modules/kafka/README.md)
- [**Мониторинг (Portainer)**](./infra/terraform/modules/monitoring/README.md)
