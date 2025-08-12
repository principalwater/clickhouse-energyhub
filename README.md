# 🚀 ClickHouse EnergyHub

**Современная платформа Data Warehouse для энергетической отрасли**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.11+](https://img.shields.io/badge/python-3.11+-blue.svg)](https://www.python.org/downloads/)
[![ClickHouse 23.8+](https://img.shields.io/badge/ClickHouse-23.8+-green.svg)](https://clickhouse.com/)
[![dbt 1.10+](https://img.shields.io/badge/dbt-1.10+-orange.svg)](https://www.getdbt.com/)
[![Airflow 2.7+](https://img.shields.io/badge/Airflow-2.7+-red.svg)](https://airflow.apache.org/)

## 🎯 О проекте

ClickHouse EnergyHub - это полнофункциональная платформа для сбора, обработки и анализа данных в энергетической отрасли. Система построена на современных технологиях и обеспечивает высокую производительность, масштабируемость и надежность.

### ✨ Ключевые возможности

- 🗄️ **ClickHouse кластер** с 4 узлами для аналитики в реальном времени
- 🔄 **Apache Airflow** для оркестрации данных и автоматизации процессов
- 🧹 **dbt** для трансформации данных и обеспечения качества
- 📊 **Автоматическая дедупликация** данных каждые 5 минут
- 🔍 **Динамическое обновление** dbt источников на основе ClickHouse
- 📈 **Superset & Metabase** для визуализации и самообслуживания
- 🚀 **CI/CD пайплайн** для автоматизации развертывания
- 📋 **Terraform** для управления инфраструктурой как код

## 🏗️ Архитектура

Система построена по принципам **Data Vault 2.0** с элементами **Kimball Dimensional Modeling**:

```mermaid
graph TB
    %% Источники данных
    subgraph "🌊 Data Sources"
        KAFKA[Kafka Topics<br/>energy_data_1min<br/>energy_data_5min]
        API[External APIs<br/>Energy Market<br/>River Sensors]
        FILES[File Sources<br/>CSV, JSON, XML]
    end
    
    %% Слои данных
    subgraph "📊 Data Layers"
        subgraph "📥 Raw Layer"
            RAW[Сырые данные<br/>• Иммутабельность<br/>• Полнота<br/>• Аудит]
        end
        
        subgraph "🔧 ODS Layer"
            ODS[Операционные данные<br/>• Очистка<br/>• Стандартизация<br/>• Валидация]
        end
        
        subgraph "🧹 DDS Layer"
            DDS[Детализированные данные<br/>• Дедупликация<br/>• Бизнес-логика<br/>• Интеграция]
        end
        
        subgraph "📈 CDM Layer"
            CDM[Аналитические кубы<br/>• KPI & метрики<br/>• Денормализация<br/>• Агрегация]
        end
    end
    
    %% ClickHouse кластер
    subgraph "🗄️ ClickHouse Cluster dwh_prod"
        subgraph "Shard 1"
            CH1[clickhouse-01<br/>Replica 1]
            CH3[clickhouse-03<br/>Replica 2]
        end
        subgraph "Shard 2"
            CH2[clickhouse-02<br/>Replica 1]
            CH4[clickhouse-04<br/>Replica 2]
        end
        subgraph "Coordination"
            CHK1[Keeper 1]
            CHK2[Keeper 2]
            CHK3[Keeper 3]
        end
    end
    
    %% BI инструменты
    subgraph "📊 BI & Analytics"
        SUPERSET[Apache Superset<br/>Аналитические дашборды]
        METABASE[Metabase<br/>Самообслуживание]
        GRAFANA[Grafana<br/>Мониторинг]
    end
    
    %% Потоки данных
    KAFKA --> RAW
    API --> RAW
    FILES --> RAW
    
    RAW --> ODS
    ODS --> DDS
    DDS --> CDM
    
    %% ClickHouse кластер
    RAW -.-> CH1
    RAW -.-> CH3
    ODS -.-> CH2
    ODS -.-> CH4
    
    %% BI доступ
    CDM --> SUPERSET
    CDM --> METABASE
    CDM --> GRAFANA
    
    %% Стили
    classDef source fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef layer fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    classDef cluster fill:#e8f5e8,stroke:#388e3c,stroke-width:2px
    classDef bi fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    
    class KAFKA,API,FILES source
    class RAW,ODS,DDS,CDM layer
    class CH1,CH2,CH3,CH4,CHK1,CHK2,CHK3 cluster
    class SUPERSET,METABASE,GRAFANA bi
```

### 🔄 Поток данных

```mermaid
flowchart LR
    subgraph "🌊 Sources"
        S1[Kafka Streams]
        S2[External APIs]
        S3[File Uploads]
    end
    
    subgraph "🔄 Processing"
        INGEST[Ingestion<br/>ClickHouse]
        VALIDATE[Validation<br/>Data Quality]
        CLEAN[Cleaning<br/>Standardization]
        BUSINESS[Business Logic<br/>Transformation]
        ANALYTICS[Analytics<br/>Aggregation]
    end
    
    subgraph "📊 Output"
        REPORT[Reporting<br/>Dashboards]
        API_OUT[API Endpoints]
        EXPORT[Data Export]
    end
    
    S1 --> INGEST
    S2 --> INGEST
    S3 --> INGEST
    
    INGEST --> VALIDATE
    VALIDATE --> CLEAN
    CLEAN --> BUSINESS
    BUSINESS --> ANALYTICS
    
    ANALYTICS --> REPORT
    ANALYTICS --> API_OUT
    ANALYTICS --> EXPORT
    
    %% Стили
    classDef source fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef process fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef output fill:#e8f5e8,stroke:#1b5e20,stroke-width:2px
    
    class S1,S2,S3 source
    class INGEST,VALIDATE,CLEAN,BUSINESS,ANALYTICS process
    class REPORT,API_OUT,EXPORT output
```

## 🚀 Быстрый старт

**Развертывание за 15 минут!**

```bash
# 1. Клонирование репозитория
git clone https://github.com/principalwater/clickhouse-energyhub.git
cd clickhouse-energyhub

# 2. Запуск развертывания
./deploy.sh
```

**📖 Подробный туториал:** [QUICK_START.md](QUICK_START.md)

## 📚 Документация

### 🏗️ Основная документация

- **[🏗️ Архитектура DWH](docs/ARCHITECTURE.md)** - Подробное описание архитектуры, слоев данных и нейминг конвенций
- **[🔗 Интеграция dbt с ClickHouse](docs/DBT_INTEGRATION.md)** - Полное руководство по работе с dbt моделями, тестами и макросами
- **[🚀 CI/CD Pipeline](docs/CI_CD.md)** - Автоматизация разработки, тестирования и развертывания

### 🔧 Специализированная документация

- **[🔄 DAG Deduplication Pipeline](docs/README_deduplication.md)** - Автоматическая очистка дублей и обновление источников
- **[💾 ClickHouse Backup Pipeline](docs/README_clickhouse_backup.md)** - Система резервного копирования и восстановления
- **[🚀 Руководство по развертыванию](docs/DEPLOYMENT.md)** - Подробное руководство по развертыванию системы
- **[☁️ Настройка Apache Airflow](docs/AIRFLOW_SETUP.md)** - Конфигурация и настройка Airflow
- **[💾 Руководство по резервному копированию](docs/BACKUP_GUIDE.md)** - Система бэкапов и восстановления
- **[📊 Создание таблиц из Kafka](docs/KAFKA_TO_CH_TABLE_CREATE_README.md)** - DAG для динамического создания таблиц

### 📁 Структура проекта

```
clickhouse-energyhub/
├── README.md                  # Основной файл проекта
├── QUICK_START.md            # Быстрый старт и развертывание
├── 📚 docs/                    # Документация проекта
│   ├── ARCHITECTURE.md        # Архитектура DWH
│   ├── DBT_INTEGRATION.md     # Интеграция dbt
│   ├── CI_CD.md               # CI/CD пайплайн
│   ├── DEPLOYMENT.md          # Руководство по развертыванию
│   ├── AIRFLOW_SETUP.md       # Настройка Apache Airflow
│   ├── BACKUP_GUIDE.md        # Руководство по резервному копированию
│   ├── KAFKA_TO_CH_TABLE_CREATE_README.md # Создание таблиц из Kafka
│   ├── README_deduplication.md # DAG дедупликации
│   └── README_clickhouse_backup.md # DAG бэкапов
├── 🏗️ infra/                   # Инфраструктура
│   ├── terraform/             # Terraform конфигурация
│   └── docker/                # Docker конфигурация
├── 🔄 airflow/                 # Apache Airflow
│   └── dags/                  # DAG'и для оркестрации
├── 🧹 dbt/                     # dbt проекты
│   ├── models/                # Модели данных
│   ├── tests/                 # Тесты
│   └── tools/                 # Утилиты
├── 📜 scripts/                 # Скрипты автоматизации
├── 🧪 tests/                   # Тесты проекта
└── 📋 deploy.sh                # Скрипт развертывания
```

## 🌟 Основные компоненты

### 🗄️ ClickHouse Cluster

- **4 узла** с репликацией и шардированием
- **Высокая производительность** для аналитических запросов
- **Автоматическое масштабирование** и балансировка нагрузки
- **Встроенная система** резервного копирования

### 🔄 Apache Airflow

- **Оркестрация** всех процессов обработки данных
- **Планировщик задач** с настраиваемым расписанием
- **Мониторинг** выполнения и уведомления об ошибках
- **Интеграция** с ClickHouse и dbt

### 🧹 dbt (data build tool)

- **Трансформация данных** через SQL
- **Автоматическое тестирование** качества данных
- **Документация** моделей и источников
- **Версионирование** схемы данных

### 📊 Визуализация

- **Apache Superset** - аналитические дашборды
- **Metabase** - самообслуживание аналитики
- **Grafana** - мониторинг и алерты

## 🔄 Автоматизация

### 🧹 Система дедупликации

**DAG `deduplication_pipeline`** автоматически:

- 🔄 **Обновляет dbt sources** на основе таблиц в ClickHouse
- 🧹 **Удаляет дубли** из `raw.river_flow` и `ods.market_data`
- 📊 **Создает очищенные таблицы** в слое DDS
- ✅ **Запускает тесты** для проверки качества данных
- 📈 **Генерирует отчеты** по результатам обработки

**Расписание:** Каждые 5 минут

### 💾 Система резервного копирования

**DAG `clickhouse_backup_pipeline`** обеспечивает:

- 💾 **Создание бэкапов** ClickHouse
- 📋 **Верификацию** целостности бэкапов
- 🔄 **Восстановление** данных при необходимости
- 🧹 **Очистку** старых бэкапов
- 📊 **Мониторинг** здоровья системы

## 🚀 CI/CD Pipeline

### 🔄 Автоматизация разработки

- **GitHub Actions** для непрерывной интеграции
- **Автоматическое тестирование** кода и инфраструктуры
- **Сканирование безопасности** и зависимостей
- **Автоматическое развертывание** через Terraform

### 🧪 Качество кода

- **Linting** с flake8, black, isort
- **Unit тесты** с pytest
- **Интеграционные тесты** для всех компонентов
- **Coverage отчеты** и quality gates

## 📊 Мониторинг и метрики

### 🔍 Ключевые метрики

- **Data Freshness** - актуальность данных
- **Data Quality** - качество данных
- **Processing Time** - время обработки
- **Error Rate** - частота ошибок
- **Storage Usage** - использование хранилища

### 🚨 Алерты

- **Pipeline Failures** - сбои в пайплайнах
- **Data Quality Issues** - проблемы с качеством
- **Performance Degradation** - деградация производительности
- **Storage Thresholds** - превышение лимитов

## 🛠️ Технологический стек

### 🗄️ База данных
- **ClickHouse** - аналитическая СУБД
- **PostgreSQL** - метаданные и конфигурация
- **Redis** - кэширование и очереди

### 🔄 Оркестрация
- **Apache Airflow** - планировщик задач
- **dbt** - трансформация данных
- **Kafka** - потоковая обработка

### 🏗️ Инфраструктура
- **Docker** - контейнеризация
- **Terraform** - инфраструктура как код
- **Portainer** - управление контейнерами

### 🧪 Тестирование и качество
- **pytest** - фреймворк тестирования
- **flake8, black, isort** - линтеры и форматтеры
- **CodeQL** - анализ безопасности
- **Trivy** - сканирование контейнеров

## 🔮 Планы развития

### 🎯 Краткосрочные (3-6 месяцев)
- [ ] Реализация Data Lineage
- [ ] Автоматизация тестирования данных
- [ ] Улучшение мониторинга
- [ ] Machine Learning модели

### 🚀 Среднесрочные (6-12 месяцев)
- [ ] Real-time Analytics
- [ ] Расширенные интеграции
- [ ] Multi-cloud архитектура
- [ ] Advanced Analytics Platform

### 🌟 Долгосрочные (1+ год)
- [ ] AI-powered Insights
- [ ] Automated Data Governance
- [ ] Edge Computing интеграция
- [ ] Quantum Computing готовность

## 🤝 Участие в проекте

### 📝 Как внести вклад

1. **Fork** репозитория
2. **Создайте** feature branch (`git checkout -b feature/amazing-feature`)
3. **Зафиксируйте** изменения (`git commit -m 'Add amazing feature'`)
4. **Push** в branch (`git push origin feature/amazing-feature`)
5. **Откройте** Pull Request

### 🐛 Сообщение об ошибках

- Используйте [GitHub Issues](https://github.com/principalwater/clickhouse-energyhub/issues)
- Опишите проблему подробно
- Приложите логи и скриншоты
- Укажите версии компонентов

### 💡 Предложения

- Создайте [GitHub Discussion](https://github.com/principalwater/clickhouse-energyhub/discussions)
- Опишите идею и обоснование
- Обсудите с сообществом
- Создайте прототип при необходимости

## 📄 Лицензия

Этот проект распространяется под лицензией MIT. См. файл [LICENSE](LICENSE) для подробностей.

## 🙏 Благодарности

- **ClickHouse Team** за отличную аналитическую СУБД
- **Apache Airflow** за мощную оркестрацию данных
- **dbt Labs** за инструмент трансформации данных
- **Сообщество** за вклад и поддержку

## 📞 Поддержка

### 🔗 Полезные ссылки

- **Документация:** [docs/](docs/)
- **Issues:** [GitHub Issues](https://github.com/principalwater/clickhouse-energyhub/issues)
- **Discussions:** [GitHub Discussions](https://github.com/principalwater/clickhouse-energyhub/discussions)
- **Wiki:** [GitHub Wiki](https://github.com/principalwater/clickhouse-energyhub/wiki)

### 📧 Контакты

- **Developer:** [principalwater](https://github.com/principalwater)

---

**⭐ Если проект вам понравился, поставьте звездочку!**
