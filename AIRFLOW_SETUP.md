# Настройка Airflow для Energy Hub

## Обзор

Мы создали полную систему генерации и обработки данных с использованием Apache Airflow. DAG'и перемещены из `volumes/airflow/dags` в `airflow/dags` для лучшего контроля версий.

## Структура проекта

```
├── airflow/                    # DAG'и Airflow (в git)
│   ├── dags/
│   │   ├── data_generation_pipeline.py    # Речной сток (каждую минуту)
│   │   ├── market_data_pipeline.py        # Рыночные данные (каждые 5 минут)
│   │   ├── static_data_pipeline.py        # Статические данные (раз в день)
│   │   ├── data_processing_pipeline.py    # Обработка слоев (каждые 15 минут)
│   │   └── energy_data_pipeline.py        # Основной пайплайн (каждый час)
│   └── README.md
├── scripts/                    # Скрипты для DAG'ов (в git)
│   ├── clickhouse_utils.py     # Утилиты для ClickHouse
│   ├── generate_static_data.py # Генерация статических данных
│   ├── nordpool_api_client.py  # Клиент Nord Pool API
│   ├── requirements.txt        # Зависимости Python
│   ├── test_airflow_setup.py   # Тестовый скрипт
│   └── kafka_producer/         # Генераторы Kafka данных
└── volumes/                    # Данные (не в git)
    └── airflow/
        ├── logs/               # Логи Airflow
        ├── plugins/            # Плагины
        └── config/             # Конфигурация
```

## DAG'и и их назначение

### 1. Генерация данных речного стока
- **Файл:** `data_generation_pipeline.py`
- **Расписание:** Каждую минуту
- **Функция:** Генерирует данные о речном стоке и отправляет в Kafka топик `energy_data_1min`

### 2. Генерация рыночных данных
- **Файл:** `market_data_pipeline.py`
- **Расписание:** Каждые 5 минут
- **Функция:** Генерирует рыночные данные (с возможностью интеграции с Nord Pool API)

### 3. Генерация статических данных
- **Файл:** `static_data_pipeline.py`
- **Расписание:** Каждый день в 2:00
- **Функция:** Создает справочные данные (устройства, локации, потребление, погода)

### 4. Обработка данных через слои
- **Файл:** `data_processing_pipeline.py`
- **Расписание:** Каждые 15 минут
- **Функция:** Обрабатывает данные через слои raw → ods → dds → cdm с помощью dbt

## Развертывание

### 1. Подготовка
```bash
# Убедитесь, что все файлы добавлены в git
git add airflow/ scripts/ infra/terraform/
git commit -m "Add Airflow DAGs and data generation scripts"
```

### 2. Развертывание инфраструктуры
```bash
# Запуск развертывания
./deploy.sh

# Или с указанием типа хранилища
./deploy.sh local_storage
```

### 3. Проверка развертывания
```bash
# Проверка статуса контейнеров
docker ps | grep airflow

# Проверка логов Airflow
docker logs airflow-api-server
docker logs airflow-scheduler
```

### 4. Доступ к Airflow UI
- **URL:** http://localhost:8080
- **Логин:** admin
- **Пароль:** (из Terraform.tfvars)

## Тестирование

### Запуск тестового скрипта
```bash
# В контейнере Airflow
docker exec -it airflow-api-server python /opt/airflow/scripts/test_airflow_setup.py
```

### Ручное тестирование DAG'ов
1. Откройте Airflow UI: http://localhost:8080
2. Найдите нужный DAG в списке
3. Нажмите "Trigger DAG" для ручного запуска
4. Проверьте логи выполнения

## Мониторинг

### Логи
- **Airflow UI:** Встроенный просмотр логов
- **Файлы:** `volumes/airflow/logs/`

### Метрики
- **Airflow:** Встроенные метрики в UI
- **Docker:** `docker stats` для мониторинга контейнеров

## Устранение неполадок

### Проблемы с зависимостями
```bash
# Проверка установленных пакетов
docker exec -it airflow-api-server pip list

# Переустановка зависимостей
docker exec -it airflow-api-server pip install -r /opt/airflow/scripts/requirements.txt
```

### Проблемы с подключениями
```bash
# Проверка подключений в Airflow
docker exec -it airflow-api-server airflow connections list

# Создание подключения вручную
docker exec -it airflow-api-server airflow connections add \
  'clickhouse_default' \
  --conn-type 'http' \
  --conn-host 'clickhouse-1' \
  --conn-port '8123' \
  --conn-login 'bi_user' \
  --conn-password 'bi_password'
```

### Проблемы с DAG'ами
```bash
# Проверка синтаксиса DAG'ов
docker exec -it airflow-api-server python -c "
from airflow.models import DagBag
dagbag = DagBag('/opt/airflow/dags')
print('DAGs loaded:', dagbag.dag_ids)
print('Errors:', dagbag.import_errors)
"
```

## Интеграция с Nord Pool API

Для использования реальных данных Nord Pool API:

1. Обновите `market_data_pipeline.py` для использования `nordpool_api_client.py`
2. Добавьте необходимые переменные окружения
3. Протестируйте подключение к API

## Расширение функциональности

### Добавление нового DAG'а
1. Создайте файл в `airflow/dags/`
2. Следуйте структуре существующих DAG'ов
3. Добавьте в git и перезапустите Airflow

### Добавление новых скриптов
1. Создайте файл в `scripts/`
2. Обновите `requirements.txt` при необходимости
3. Добавьте в git

## Безопасность

- Все секреты хранятся в Terraform.tfvars (не в git)
- Используется Fernet шифрование для Airflow
- Подключения к базам данных через переменные окружения

## Резервное копирование

- **DAG'и:** В git репозитории
- **Логи:** В `volumes/airflow/logs/`
- **Конфигурация:** В `volumes/airflow/config/`

## Обновления

При обновлении DAG'ов:
1. Внесите изменения в `airflow/dags/`
2. Закоммитьте в git
3. Перезапустите Airflow контейнеры или дождитесь автоматического обновления
