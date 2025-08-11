# ClickHouse EnergyHub - Инфраструктура

## 🏗️ Обзор

Инфраструктура ClickHouse EnergyHub построена с использованием Terraform и Docker, обеспечивая автоматизированное развертывание всех компонентов системы.

## 🎯 Компоненты инфраструктуры

### 1. **ClickHouse Cluster** (`terraform/modules/clickhouse-cluster/`)
- Высопроизводительный кластер ClickHouse для аналитики
- 4 ноды (2 шарда по 2 реплики) + 3 ноды ClickHouse Keeper
- Поддержка различных типов хранения (локальный, S3)
- [Подробнее →](terraform/modules/clickhouse-cluster/README.md)

### 2. **Apache Kafka** (`terraform/modules/kafka/`)
- Брокер сообщений для потоковой обработки данных
- SSL/TLS шифрование и SASL/SCRAM аутентификация
- Автоматическое создание топиков с TTL
- [Подробнее →](terraform/modules/kafka/README.md)

### 3. **PostgreSQL** (`terraform/modules/postgres/`)
- Централизованная база данных для метаданных
- Единый экземпляр с отдельными пользователями для сервисов
- Production-ready конфигурация с health checks
- [Подробнее →](terraform/modules/postgres/README.md)

### 4. **Apache Airflow 3.0.4** (`terraform/modules/airflow/`)
- Современная платформа для оркестрации задач
- Новая архитектура 3.0.4 с отдельными компонентами
- Автоматическая интеграция с ClickHouse и Kafka
- [Подробнее →](terraform/modules/airflow/README.md)

### 5. **BI Infrastructure** (`terraform/modules/bi-infra/`)
- Инструменты для визуализации данных
- Metabase и Apache Superset
- Автоматическая настройка подключений
- [Подробнее →](terraform/modules/bi-infra/README.md)

### 6. **Monitoring** (`terraform/modules/monitoring/`)
- Portainer Community Edition для управления контейнерами
- Веб-интерфейс для мониторинга и управления
- [Подробнее →](terraform/modules/monitoring/README.md)

## 🚀 Быстрый старт

### Предварительные требования

- Terraform 1.0+
- Docker и Docker Compose
- Доступ к GitHub Secrets (для CI/CD)

### Развертывание

1. **Инициализация**
```bash
cd infra/terraform
terraform init
```

2. **Настройка переменных**
```bash
# Скопируйте и настройте переменные
cp env/terraform.tfvars.example terraform.tfvars
```

3. **Развертывание**
```bash
terraform plan
terraform apply
```

## 🔧 Управление

### Основные команды

```bash
# Планирование изменений
terraform plan

# Применение изменений
terraform apply

# Удаление инфраструктуры
terraform destroy

# Обновление отдельных модулей
terraform apply -target="module.clickhouse_cluster"
terraform apply -target="module.kafka"
terraform apply -target="module.airflow"
```

### Мониторинг

- **Portainer**: http://localhost:9443
- **ClickHouse**: http://localhost:8123
- **Kafka**: localhost:9093
- **PostgreSQL**: localhost:5432

## 🔐 Безопасность

### Секреты и переменные

- **GitHub Secrets** для CI/CD
- **Переменные окружения** для локальной разработки
- **SSL/TLS сертификаты** для Kafka
- **Аутентификация** для всех сервисов

### Сетевая безопасность

- **Docker networks** для изоляции сервисов
- **Порты** открываются только для необходимых сервисов
- **Внутренние коммуникации** через Docker networks

## 📊 CI/CD Integration

Инфраструктура интегрирована в GitHub Actions CI/CD pipeline:

- ✅ **Terraform Validation** - Проверка конфигурации
- ✅ **Format Check** - Проверка форматирования кода
- ✅ **Plan Generation** - Создание планов развертывания
- ✅ **Security Checks** - Проверка безопасности

## 🏗️ Архитектура развертывания

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Terraform     │    │   Docker        │    │   Services      │
│   Configuration │───▶│   Compose       │───▶│   Running       │
│                 │    │                 │    │                 │
│ • Modules       │    │ • Containers    │    │ • ClickHouse    │
│ • Variables     │    │ • Networks      │    │ • Kafka         │
│ • Dependencies  │    │ • Volumes       │    │ • Airflow       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🔍 Troubleshooting

### Частые проблемы

1. **Ошибки Docker**
   - Проверьте статус Docker daemon
   - Убедитесь в доступности портов

2. **Ошибки Terraform**
   - Проверьте версию Terraform
   - Убедитесь в корректности переменных

3. **Проблемы с сервисами**
   - Проверьте логи контейнеров
   - Убедитесь в доступности зависимостей

### Логи и отладка

```bash
# Логи контейнеров
docker logs <container_name>

# Статус сервисов
docker ps

# Проверка сетей
docker network ls
```

## 📚 Документация модулей

- [ClickHouse Cluster](terraform/modules/clickhouse-cluster/README.md)
- [Kafka](terraform/modules/kafka/README.md)
- [PostgreSQL](terraform/modules/postgres/README.md)
- [Apache Airflow](terraform/modules/airflow/README.md)
- [BI Infrastructure](terraform/modules/bi-infra/README.md)
- [Monitoring](terraform/modules/monitoring/README.md)

## 🤝 Поддержка

Для вопросов по инфраструктуре:
- Создавайте Issues в репозитории
- Обращайтесь к команде DevOps
- Проверяйте логи и документацию модулей

---

**Версия**: 1.0.0  
**Последнее обновление**: 2025-01-27  
**Статус**: Активная разработка
