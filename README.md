# clickhouse-energyhub

## Проектирование масштабируемой аналитической платформы для рынка электроэнергии на базе ClickHouse

### Решаемая проблема

Энергетические рынки России и стран ЕАЭС страдают от непрозрачности и разнородности источников данных - отчёты публикуются в разрозненных форматах (PDF, Excel, веб-страницы), отсутствует единый API-доступ, а биржевые данные зачастую платные или устаревшие. Это тормозит интеграцию национальных рынков, мешает построению общего электроэнергетического рынка и затрудняет применение data-driven подходов в принятии решений — как в бизнесе, так и в исследовательских инициативах.

**Проект направлен на построение аналитической платформы, которая:**
*   агрегирует данные из открытых, синтетических и стриминговых источников (включая 5-минутные цены)
*   унифицирует структуру хранения и обработки через ClickHouse
*   предоставляет прозрачный, быстрый и расширяемый набор витрин данных для BI/исследований/ML через open-source стек

---

### Архитектура

#### MVP
Компоненты:
*   **Источник данных:** open-data CSV из Nord Pool, псевдо-стрим от Python-генератора.
*   **Ingestion:**
    *   batch DAG в Airflow (ночная загрузка исторических цен),
    *   Kafka topic `price_5m`, заполняемый Python producer каждые 5 мин.
*   **ETL/Transform:** dbt (слои staging и marts), базовые DQ проверки (timezone, дубли).
*   **Хранилище:** ClickHouse (базовый кластер, 2 шарда по 2 реплики, 3 ноды кипера), 3 схемы: `prices_batch`, `prices_stream`, `prices_mart`.
*   **Мониторинг:** Prometheus + Grafana (задержка ingestion, объемы, ошибки).
*   **BI:** 1 дашборд в Metabase/Superset с отображением спотовых цен по зонам, etc.
*   **CI/CD:** GitHub Actions, Terraform-пайплайн.
*   **Документация:** README, архитектурная диаграмма, туториал запуска.

#### Финальная реализация
Предполагается, что будут охвачены все ключевые сценарии продакшн-уровня: отказоустойчивость, API-доступ, расширенные источники и наблюдаемость.
*   **Хранилище:** ClickHouse кластер: 2 шарда × 2 реплики, распределённые таблицы, BACKUP TO S3.
*   **Ingestion:** Kafka (NiFi + Debezium, etc.): многоканальный ingestion (API SMHI, ФГБУ ЦДУ, ГЭС балансы).
*   **Streaming:** Kafka Connect + Schema Registry; топики `load_15m`, `weather_hourly`, `price_5m`, etc.
*   **ETL:** dbt слои core, marts; Great Expectations с cron-валидацией.
*   **BI/API:** Superset Embedded + FastAPI API с rate-limit, выдающим агрегации по зонам/датам; готовые операционные дашборды.
*   **Monitoring:** Grafana: CPU, I/O, ingestion latency; Loki + Promtail; алерты по условным SLA.
*   **DevOps:** CI-пайплайн: lint dbt, docker, deploy в k8s через Helm.
*   **Документация:** Google Doc требований, презентация, туториал «разверни за 15 минут».

---

### Схема интеграции компонентов

```mermaid
graph TD
    terraform -->|Создаёт| k8s[(Kubernetes Cluster)]
    docker -->|Образы| registry[(Docker Registry)]
    registry -->|pulls| k8s
    subgraph k8s
      clickhouse[(ClickHouse)]
      kafka[(Kafka/ZK/Schema)]
      airflow[(Airflow/Dbt)]
      fastapi[(FastAPI API)]
      superset[(Superset/Metabase)]
      prometheus[(Prometheus)]
      grafana[(Grafana)]
    end
    k8s --> S3[(S3/BACKUP, Monitoring, Raw/Curated Data)]
    prometheus -->|alerts| slack[(Slack/Alerting)]
