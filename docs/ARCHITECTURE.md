# 🏗️ Архитектура Data Warehouse (DWH)

## Обзор системы

ClickHouse EnergyHub представляет собой современную архитектуру Data Warehouse, построенную на принципах **Data Vault 2.0** с элементами **Kimball Dimensional Modeling**. Система обеспечивает высокую производительность, масштабируемость и гибкость для энергетической отрасли.

## 🏛️ Архитектурные слои

### 1. **Raw Layer** (Сырые данные)
**Назначение:** Хранение исходных данных без изменений

**Характеристики:**
- ✅ **Иммутабельность** - данные никогда не изменяются
- ✅ **Полнота** - сохраняются все входящие данные
- ✅ **Аудит** - полная история изменений
- ✅ **Производительность** - быстрая запись

**Структура:**
```
raw/
├── river_flow/           # Данные о речном стоке
├── energy_consumption/   # Потребление энергии
├── market_data/          # Рыночные данные
├── devices/              # Информация об устройствах
└── locations/            # Географические данные
```

**Нейминг конвенции:**
- Таблицы: `raw_[entity_name]`
- Колонки: `[original_name]` (без префиксов)
- Индексы: `idx_[table]_[columns]`

### 2. **ODS Layer** (Operational Data Store)
**Назначение:** Операционные данные с базовой очисткой

**Характеристики:**
- 🔧 **Базовая очистка** - удаление очевидных ошибок
- 📊 **Стандартизация** - приведение к единому формату
- 🔄 **Инкрементальная загрузка** - обновление измененных данных
- 📈 **Бизнес-логика** - применение простых правил

**Структура:**
```
ods/
├── ods_river_flow/       # Очищенные данные речного стока
├── ods_energy_consumption/ # Очищенные данные потребления
├── ods_market_data/      # Очищенные рыночные данные
├── ods_devices/          # Очищенные данные устройств
└── ods_locations/        # Очищенные географические данные
```

**Нейминг конвенции:**
- Таблицы: `ods_[entity_name]`
- Колонки: `[standardized_name]`
- Индексы: `idx_ods_[table]_[columns]`

### 3. **DDS Layer** (Detailed Data Store)
**Назначение:** Детализированные данные с бизнес-логикой

**Характеристики:**
- 🧹 **Дедупликация** - удаление дублирующихся записей
- 🔗 **Интеграция** - объединение данных из разных источников
- 📊 **Агрегация** - предрасчет метрик
- 🎯 **Бизнес-правила** - применение сложной логики

**Структура:**
```
dds/
├── dds_river_flow_clean/     # Очищенные данные без дублей
├── dds_market_data_clean/    # Очищенные рыночные данные
├── dds_energy_consumption/   # Обработанные данные потребления
├── dds_river_flow_view/      # View для доступа к данным
└── dds_market_data_view/     # View для доступа к данным
```

**Нейминг конвенции:**
- Таблицы: `dds_[entity_name]_[suffix]`
- Колонки: `[business_name]`
- Индексы: `idx_dds_[table]_[columns]`

### 4. **CDM Layer** (Conformed Data Mart)
**Назначение:** Готовые для анализа данные

**Характеристики:**
- 📊 **Денормализация** - оптимизация для запросов
- 🎯 **Бизнес-метрики** - готовые KPI
- 📈 **Временные ряды** - агрегация по времени
- 🔍 **Аналитические кубы** - многомерный анализ

**Структура:**
```
cdm/
├── cdm_daily_energy_summary/     # Ежедневная сводка по энергии
├── cdm_monthly_river_flow/       # Месячная сводка по речному стоку
├── cdm_market_analytics/         # Аналитика рынка
└── cdm_device_performance/       # Производительность устройств
```

**Нейминг конвенции:**
- Таблицы: `cdm_[granularity]_[entity]_[type]`
- Колонки: `[metric_name]` или `[dimension_name]`
- Индексы: `idx_cdm_[table]_[columns]`

## 🔄 Поток данных

```
External Sources → Raw Layer → ODS Layer → DDS Layer → CDM Layer → BI Tools
     ↓              ↓          ↓          ↓          ↓          ↓
  Ingestion    Validation  Cleaning   Business    Analytics  Reporting
              & Audit     & ETL      Logic      & Aggregation
```

### Детализация потоков:

#### 1. **Ingestion Flow**
```
API/File → Kafka → Raw Tables → Validation → ODS Tables
```

#### 2. **Processing Flow**
```
ODS → dbt Models → DDS Clean Tables → Business Logic → DDS Views
```

#### 3. **Analytics Flow**
```
DDS → Aggregation → CDM Tables → BI Tools → Dashboards
```

## 🏗️ Технологический стек

### **База данных**
- **ClickHouse** - основная СУБД для аналитики
- **PostgreSQL** - метаданные и конфигурация
- **Redis** - кэширование и очереди

### **Оркестрация**
- **Apache Airflow** - планировщик задач
- **dbt** - трансформация данных
- **Kafka** - потоковая обработка

### **Визуализация**
- **Apache Superset** - аналитические дашборды
- **Metabase** - самообслуживание аналитики
- **Grafana** - мониторинг и алерты

### **Инфраструктура**
- **Docker** - контейнеризация
- **Terraform** - инфраструктура как код
- **Portainer** - управление контейнерами

## 📊 Модели данных

### **Entity-Relationship Model**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│    Locations    │    │     Devices     │    │ Energy Meters   │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ location_id (PK)│◄───┤ location_id (FK)│◄───┤ device_id (FK)  │
│ location_name   │    │ device_id (PK)  │    │ meter_id (PK)   │
│ region          │    │ device_type     │    │ timestamp       │
│ coordinates     │    │ manufacturer    │    │ energy_kwh      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   River Flow    │    │ Market Data     │    │ Energy Prices   │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ flow_id (PK)    │    │ market_id (PK)  │    │ price_id (PK)   │
│ location_id (FK)│    │ timestamp       │    │ timestamp       │
│ timestamp       │    │ trading_zone    │    │ region          │
│ water_level     │    │ volume_mwh      │    │ price_eur_mwh   │
│ flow_rate       │    │ price_eur_mwh   │    └─────────────────┘
└─────────────────┘    └─────────────────┘
```

### **Dimensional Model (CDM)**

```
┌─────────────────────────────────────────────────────────────┐
│                    Fact Table: Energy Facts                 │
├─────────────────────────────────────────────────────────────┤
│ fact_id (PK)                                                │
│ timestamp (FK) → Date Dimension                             │
│ location_id (FK) → Location Dimension                       │
│ device_id (FK) → Device Dimension                           │
│ energy_kwh (Measure)                                        │
│ cost_eur (Measure)                                          │
│ efficiency_ratio (Measure)                                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Date Dimension  │    │Location Dimension    │Device Dimension │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ date_id (PK)    │    │ location_id (PK)│    │ device_id (PK)  │
│ date            │    │ location_name   │    │ device_name     │
│ day_of_week     │    │ region          │    │ device_type     │
│ month           │    │ city            │    │ manufacturer    │
│ quarter         │    │ country         │    │ model           │
│ year            │    │ coordinates     │    │ capacity_mw     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🎯 Нейминг конвенции

### **Общие принципы**
- **Snake_case** для всех имен
- **Префиксы** для обозначения слоя
- **Суффиксы** для типа объекта
- **Английский язык** для всех имен

### **Слои данных**
```
raw_*          # Сырые данные
ods_*          # Операционные данные
dds_*_clean    # Очищенные детализированные данные
dds_*_view     # Представления над данными
cdm_*_*        # Конформированные данные
```

### **Типы объектов**
```
*_local        # Локальные таблицы ClickHouse
*_mv           # Materialized Views
*_view         # Обычные представления
*_clean        # Очищенные данные
*_summary      # Сводные данные
*_analytics    # Аналитические данные
```

### **Колонки**
```
*_id           # Идентификаторы (PK/FK)
*_name         # Названия
*_type         # Типы
*_date         # Даты
*_timestamp    # Временные метки
*_amount       # Количества
*_price        # Цены
*_rate         # Ставки
*_level        # Уровни
*_status       # Статусы
*_created_at   # Время создания
*_updated_at   # Время обновления
```

### **Индексы**
```
idx_[table]_[columns]           # Обычные индексы
idx_[table]_[columns]_partial   # Частичные индексы
idx_[table]_[columns]_unique    # Уникальные индексы
```

## 🔧 Конфигурация ClickHouse

### **Движки таблиц**
```sql
-- Для Raw и ODS слоев
ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (timestamp, entity_id)

-- Для DDS слоев
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/table_name', '{replica}')
PARTITION BY toYYYYMM(timestamp)
ORDER BY (business_key, timestamp)

-- Для CDM слоев
ENGINE = ReplicatedSummingMergeTree('/clickhouse/tables/{shard}/table_name', '{replica}')
PARTITION BY toYYYYMM(timestamp)
ORDER BY (dimension_keys)
```

### **Настройки производительности**
```sql
-- Оптимизация для аналитических запросов
SET optimize_aggregation_in_order = 1;
SET max_threads = 8;
SET max_memory_usage = 8589934592; -- 8GB
```

## 📈 Мониторинг и метрики

### **Ключевые метрики**
- **Data Freshness** - актуальность данных
- **Data Quality** - качество данных
- **Processing Time** - время обработки
- **Error Rate** - частота ошибок
- **Storage Usage** - использование хранилища

### **Алерты**
- **Data Pipeline Failures** - сбои в пайплайнах
- **Data Quality Issues** - проблемы с качеством
- **Performance Degradation** - деградация производительности
- **Storage Thresholds** - превышение лимитов хранилища

## 🔮 Планы развития

### **Краткосрочные (3-6 месяцев)**
- [ ] Реализация Data Lineage
- [ ] Автоматизация тестирования данных
- [ ] Улучшение мониторинга

### **Среднесрочные (6-12 месяцев)**
- [ ] Внедрение Machine Learning
- [ ] Реализация Real-time Analytics
- [ ] Расширение интеграций

### **Долгосрочные (1+ год)**
- [ ] Multi-cloud архитектура
- [ ] Advanced Analytics Platform
- [ ] AI-powered Insights

## 📚 Дополнительные ресурсы

- [Quick Start Guide](QUICK_START.md) - Быстрый старт
- [DBT Integration](DBT_INTEGRATION.md) - Интеграция с dbt
- [Monitoring Guide](MONITORING.md) - Мониторинг системы
- [CI/CD Pipeline](CI_CD.md) - Автоматизация развертывания
