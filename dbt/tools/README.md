# 🛠️ Инструменты dbt

Эта директория содержит все необходимые скрипты для работы с dbt модулем.

## 📋 Доступные скрипты

### 🎯 `dbt-manager.sh` - Основной менеджер dbt
**Универсальный скрипт для всех операций с dbt**

```bash
# Настройка окружения
./dbt-manager.sh setup

# Проверка окружения
./dbt-manager.sh check

# Запуск моделей
./dbt-manager.sh run
./dbt-manager.sh run prod
./dbt-manager.sh run dev model_name

# Запуск тестов
./dbt-manager.sh test
./dbt-manager.sh test prod

# Компиляция моделей
./dbt-manager.sh compile

# Генерация документации
./dbt-manager.sh docs

# Запуск веб-сервера документации
./dbt-manager.sh serve

# Список моделей
./dbt-manager.sh list

# Отладочная информация
./dbt-manager.sh debug

# Справка
./dbt-manager.sh help
```

### 🔧 `activate.sh` - Активация окружения
**Быстрая активация dbt окружения**

```bash
source ./activate.sh
```

### 🔍 `diagnose.sh` - Диагностика окружения
**Проверка состояния dbt окружения**

```bash
./diagnose.sh
```

## 🚀 Быстрый старт

1. **Настройка окружения:**
   ```bash
   cd dbt/tools
   ./dbt-manager.sh setup
   ```

2. **Активация окружения:**
   ```bash
   source ./activate.sh
   ```

3. **Проверка работоспособности:**
   ```bash
   ./dbt-manager.sh check
   ```

4. **Запуск моделей:**
   ```bash
   ./dbt-manager.sh run
   ```

## 🔑 Переменные окружения

Скрипты автоматически загружают переменные из:
- `../../infra/terraform/Terraform.tfvars` (если доступен)
- Переменные окружения системы

**Обязательные переменные:**
- `CLICKHOUSE_USER` - пользователь ClickHouse (значение `super_user_name` из `terraform.tfvars`)
- `CLICKHOUSE_PASSWORD` - пароль пользователя (значение `super_user_password` из `terraform.tfvars`)
- `CLICKHOUSE_HOST` - хост ClickHouse
- `CLICKHOUSE_PORT` - порт ClickHouse
- `CLICKHOUSE_DATABASE` - база данных

## 📁 Структура

```
dbt/tools/
├── dbt-manager.sh    # Основной менеджер
├── activate.sh       # Активация окружения
├── diagnose.sh       # Диагностика
└── README.md         # Документация
```

## 💡 Рекомендации

- **Для ежедневной работы:** используйте `dbt-manager.sh`
- **Для быстрой активации:** используйте `activate.sh`
- **Для диагностики проблем:** используйте `diagnose.sh`
- **Для разработки:** используйте `dbt-manager.sh debug`

## 🔗 Связанные файлы

- `../../infra/terraform/load_env.sh` - загрузка переменных из Terraform
- `../profiles/profiles.yml` - конфигурация профилей dbt
- `../dbt_project.yml` - конфигурация проекта dbt
