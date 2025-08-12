# 🚀 Руководство по развертыванию ClickHouse EnergyHub

## 📋 Требования

Перед развертыванием убедитесь, что у вас установлены:

- **Terraform** >= 1.0
- **Docker** >= 20.0
- **Python3** >= 3.8
- **Git**

## 🚀 Быстрое развертывание

```bash
# 1. Клонирование репозитория
git clone https://github.com/principalwater/clickhouse-energyhub.git
cd clickhouse-energyhub/infra/terraform

# 2. Создание файла с переменными (копируем заполненный dummy-пример)
cp terraform.tfvars.example terraform.tfvars

# 3. Запуск развертывания
cd ../../
./deploy.sh

# Или с удаленным S3 хранилищем (требует настройки)
# ./deploy.sh s3_storage
```

Скрипт автоматически:
- ✅ Проверит наличие всех зависимостей
- ✅ Инициализирует Terraform
- ✅ Покажет план развертывания
- ✅ Развернет всю инфраструктуру
- ✅ **Создаст базу данных `otus_default` в ClickHouse**
- ✅ **Создаст тестовые таблицы для проверки**
- ✅ Настроит dbt окружение
- ✅ Покажет инструкции по использованию

**🆕 Автоматизация базы данных:**
- База данных `otus_default` создается автоматически на кластере `dwh_prod`
- Создается тестовая таблица `test_table` с данными
- Все таблицы доступны для dbt моделей

## 🔧 Ручное развертывание

Если вы предпочитаете ручное развертывание:

```bash
cd infra/terraform

# Инициализация
terraform init

# Планирование
terraform plan -var="storage_type=local_storage"

# Развертывание
terraform apply -var="storage_type=local_storage"
```

## 🔍 Проверка развертывания

### Проверка ClickHouse базы данных

```bash
cd dbt

# Проверка базы данных и таблиц
./check_database.sh
```

**Ожидаемый вывод:**
```
🔍 Проверка базы данных ClickHouse...
🌐 Проверка подключения к ClickHouse...
✅ Подключение к ClickHouse успешно

📊 Проверка базы данных otus_default...
✅ База данных otus_default найдена

📋 Проверка таблиц в otus_default...
test_table

🧪 Проверка тестовой таблицы...
Test table data:
1	test1	2024-08-12 00:30:00
2	test2	2024-08-12 00:30:00
3	test3	2024-08-12 00:30:00

✅ Проверка базы данных завершена успешно!
```

### Проверка dbt

```bash
# Проверка путей и структуры
./verify_paths.sh

# Проверка функциональности dbt
./check_dbt.sh

# Активация окружения
source activate_dbt.sh

# Проверка конфигурации
dbt debug

# Компиляция моделей
dbt compile

# Список моделей
dbt list
```

### Проверка ClickHouse

```bash
# Подключение к ClickHouse
clickhouse-client -h localhost -p 9000 -u bi_user -p bi_password

# Проверка баз данных
SHOW DATABASES;

# Проверка таблиц
SHOW TABLES FROM otus_default;
```

## 📊 Структура проекта после развертывания

```
clickhouse-energyhub/
├── dbt/                          # dbt проект
│   ├── dbt_env/                  # Python виртуальное окружение
│   ├── profiles/                 # Профили подключения
│   │   └── profiles.yml         # Конфигурация ClickHouse
│   ├── models/                   # Модели данных
│   │   ├── raw/                 # Raw модели
│   │   ├── intermediate/        # Промежуточные модели
│   │   └── marts/               # Data marts
│   ├── macros/                   # Макросы
│   ├── tests/                    # Тесты
│   ├── seeds/                    # Справочные данные
│   ├── snapshots/                # Снапшоты
│   ├── analysis/                 # Аналитические запросы
│   ├── logs/                     # Логи dbt
│   ├── target/                   # Артефакты компиляции
│   ├── dbt_project.yml          # Конфигурация проекта
│   ├── activate_dbt.sh          # Скрипт активации
│   ├── check_dbt.sh             # Скрипт проверки
│   └── verify_paths.sh          # Скрипт проверки путей
├── infra/                        # Инфраструктура
│   └── terraform/               # Terraform конфигурация
├── volumes/                      # Данные приложений (игнорируется в git)
│   ├── minio/                   # MinIO (S3 хранилище)
│   │   ├── data/                # Основные данные
│   │   ├── backup/              # Резервные копии
│   │   ├── logs/                # Логи
│   │   └── config/              # Конфигурация
│   ├── clickhouse/              # Данные ClickHouse
│   ├── postgres/                # Данные PostgreSQL
│   ├── airflow/                 # Данные Airflow
│   ├── kafka/                   # Данные Kafka
│   └── redis/                   # Данные Redis
├── deploy.sh                     # Скрипт развертывания
└── DEPLOYMENT.md                 # Это руководство (находится в docs/)
```

## 🗄️ Организация данных MinIO

### Структура директорий

```
volumes/minio/
├── data/          # Основные данные S3 хранилища
├── backup/        # Резервные копии ClickHouse
├── logs/          # Логи MinIO
└── config/        # Конфигурация MinIO
```

### Автоматическое создание

При развертывании Terraform автоматически:
- ✅ Создает структуру директорий в `volumes/`
- ✅ Настраивает MinIO для использования новых путей
- ✅ Игнорирует все данные в `.gitignore`

## 🔧 Конфигурация dbt

### Профили подключения

Профили автоматически создаются в `dbt/profiles/` и содержат:

- **dev** - для разработки (4 потока)
- **prod** - для продакшена (8 потоков)  
- **test** - для тестирования (2 потока)

### Переменные проекта

Основные переменные в `dbt_project.yml`:

```yaml
vars:
  clickhouse_database: "otus_default"
  clickhouse_cluster: "default"
  dq_enabled: true
  dq_schema: "dq_checks"
```

## 🔐 Учетные данные и переменные окружения

### Автоматическая загрузка

Все скрипты автоматически загружают учетные данные ClickHouse из `dbt/profiles/profiles.yml`:

```bash
# Скрипты автоматически загружают:
export CLICKHOUSE_USER=bi_user
export CLICKHOUSE_PASSWORD=your_password
```

### Ручная установка переменных

Если нужно установить переменные вручную:

```bash
# Установка переменных окружения
export CLICKHOUSE_USER=bi_user
export CLICKHOUSE_PASSWORD=your_password

# Или загрузка из profiles.yml
source ./load_env.sh
```

### Проверка переменных

```bash
# Проверка загруженных переменных
echo "User: $CLICKHOUSE_USER"
echo "Password: ${CLICKHOUSE_PASSWORD:0:3}***"
```

## 🚨 Устранение неполадок

### Проблема: dbt не находит профили

```bash
# Проверьте, что профили созданы
ls -la dbt/profiles/

# Установите переменную окружения
export DBT_PROFILES_DIR="$(pwd)/profiles"

# Или используйте скрипт активации
source activate_dbt.sh
```

### Проблема: Ошибка подключения к ClickHouse

```bash
# Проверьте статус ClickHouse
docker ps | grep clickhouse

# Проверьте профиль
cat dbt/profiles/profiles.yml

# Проверьте сеть Docker
docker network ls
```

### Проблема: Python окружение не активируется

```bash
# Пересоздайте окружение
cd dbt
rm -rf dbt_env
python3 -m venv dbt_env
source dbt_env/bin/activate
pip install dbt-core==1.10.7 dbt-clickhouse==1.9.2
```

## 📚 Полезные команды

### dbt команды

```bash
# Активация окружения
source activate_dbt.sh

# Проверка конфигурации
dbt debug

# Компиляция моделей
dbt compile

# Запуск моделей
dbt run

# Запуск тестов
dbt test

# Генерация документации
dbt docs generate

# Запуск документации
dbt docs serve

# Список моделей
dbt list

# Проверка зависимостей
dbt list --select +model_name
```

### Terraform команды

```bash
# Просмотр состояния
terraform show

# Просмотр выходных значений
terraform output

# Уничтожение инфраструктуры
terraform destroy

# Обновление модулей
terraform get -update
```

## 🔄 Обновление

Для обновления существующего развертывания:

```bash
cd infra/terraform
terraform plan
terraform apply
```

## 🗑️ Очистка

Для полной очистки:

```bash
cd infra/terraform
terraform destroy

# Удаление локальных файлов dbt
cd ../../dbt
rm -rf dbt_env logs target
```

## ❓ FAQ / Часто возникающие проблемы

### 🔴 Airflow зависает на фазе `setup_airflow_connections`

**Проблема:** При развертывании Airflow может зависнуть на фазе `setup_airflow_connections` после нескольких перезапусков.

**Причина:** Это известная проблема с Airflow 2.8.1, связанная с кэшированием и состоянием контейнеров.

**Решение:**
1. **Отмените деплой** нажав `Ctrl + C`
2. **Выполните скрипт очистки:**
   ```bash
   cd infra/terraform
   ./cleanup_airflow.sh
   ```
3. **Запустите деплой заново:**
   ```bash
   cd ../../
   ./deploy.sh
   ```

**Что делает скрипт очистки:**
- Останавливает и удаляет все контейнеры Airflow
- Удаляет образы Airflow
- Удаляет сеть `airflow_network`
- Подготавливает чистую среду для нового развертывания

### 🟡 Другие проблемы с Airflow

**Проблема:** Контейнеры Airflow не запускаются
**Решение:** Проверьте логи Docker и убедитесь, что порты 8080, 5555 не заняты

**Проблема:** Airflow не может подключиться к PostgreSQL
**Решение:** Убедитесь, что PostgreSQL запущен и доступен

**Проблема:** Ошибка `TypeError: Invalid arguments were passed to TelegramOperator`
**Решение:** В версии 4.8.2+ API упростился. DAG использует современный синтаксис без устаревших параметров.

**Проблема:** Telegram соединение не создается автоматически
**Решение:** Telegram соединение `telegram_default` создается автоматически при деплое, если указаны переменные `telegram_bot_token` и `telegram_chat_id` в `terraform.tfvars`.

## 📞 Поддержка

При возникновении проблем:

1. Проверьте логи: `tail -f dbt/logs/dbt.log`
2. Запустите диагностику: `./verify_paths.sh`
3. Проверьте статус: `terraform show`
4. Обратитесь к документации dbt: https://docs.getdbt.com/

---

## 📊 Следующие шаги после развертывания

После успешного развертывания инфраструктуры:

1. **Настройте BI-инструменты** → [BI_CLICKHOUSE_SETUP.md](BI_CLICKHOUSE_SETUP.md)
   - Подключение Metabase к ClickHouse
   - Подключение Superset к ClickHouse
   - Примеры создания дашбордов

**Удачного развертывания! 🎉**
