#!/bin/bash
# Скрипт для активации dbt окружения
cd /Users/principalwater/Documents/git/clickhouse-energyhub/dbt

# Устанавливаем переменную окружения для профилей
export DBT_PROFILES_DIR="/Users/principalwater/Documents/git/clickhouse-energyhub/dbt/profiles"

# Активируем виртуальное окружение
source dbt_env/bin/activate

echo "dbt environment activated"
echo "dbt version: $(dbt --version)"
echo "profiles directory: $DBT_PROFILES_DIR"
echo ""
echo "Available commands:"
echo "  dbt run - запуск моделей"
echo "  dbt test - запуск тестов"
echo "  dbt docs generate - генерация документации"
echo "  dbt docs serve - запуск документации"
echo "  dbt debug - проверка конфигурации"
echo "  dbt compile - компиляция моделей"
echo "  dbt list - список моделей"
