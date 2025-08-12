#!/bin/bash

# Скрипт для диагностики dbt окружения
# Использование: ./diagnose.sh

echo "🔍 Диагностика dbt окружения..."

# Переходим в корневую директорию dbt
cd "$(dirname "$0")/.."

# Проверяем структуру директорий
echo "📁 Проверка структуры директорий..."
REQUIRED_DIRS=("models" "macros" "tests" "seeds" "snapshots" "analysis" "logs" "target" "profiles")

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "✅ $dir"
    else
        echo "❌ $dir"
    fi
done

# Проверяем конфигурационные файлы
echo ""
echo "📋 Проверка конфигурационных файлов..."
if [ -f "dbt_project.yml" ]; then
    echo "✅ dbt_project.yml"
else
    echo "❌ dbt_project.yml"
fi

if [ -f "profiles/profiles.yml" ]; then
    echo "✅ profiles/profiles.yml"
else
    echo "❌ profiles/profiles.yml"
fi

# Проверяем Python окружение
echo ""
echo "🐍 Проверка Python окружения..."
if command -v python3 &> /dev/null; then
    echo "✅ Python3: $(python3 --version)"
else
    echo "❌ Python3 не установлен"
fi

if [ -d "dbt_env" ]; then
    echo "✅ Виртуальное окружение dbt_env"
    
    # Активируем и проверяем dbt
    source dbt_env/bin/activate
    if command -v dbt &> /dev/null; then
        echo "✅ dbt: $(dbt --version)"
    else
        echo "❌ dbt не установлен"
    fi
else
    echo "❌ Виртуальное окружение dbt_env не найдено"
fi

# Проверяем Docker и ClickHouse
echo ""
echo "🐳 Проверка Docker и ClickHouse..."
if command -v docker &> /dev/null; then
    echo "✅ Docker: $(docker --version)"
    
    if docker ps | grep -q "clickhouse-01"; then
        echo "✅ Контейнер clickhouse-01 запущен"
    else
        echo "❌ Контейнер clickhouse-01 не запущен"
    fi
else
    echo "❌ Docker не установлен"
fi

# Проверяем переменные окружения
echo ""
echo "🔧 Проверка переменных окружения..."
ENV_VARS=("CLICKHOUSE_USER" "CLICKHOUSE_PASSWORD" "CLICKHOUSE_HOST" "CLICKHOUSE_PORT" "CLICKHOUSE_DATABASE")

for var in "${ENV_VARS[@]}"; do
    if [ -n "${!var}" ]; then
        if [ "$var" = "CLICKHOUSE_PASSWORD" ]; then
            echo "✅ $var: ${!var:0:3}***"
        else
            echo "✅ $var: ${!var}"
        fi
    else
        echo "❌ $var: не установлена"
    fi
done

echo ""
echo "💡 Для загрузки переменных из Terraform.tfvars используйте:"
echo "   source ../../infra/terraform/load_env.sh"
echo ""
echo "💡 Для полной диагностики используйте:"
echo "   ./tools/dbt-manager.sh check"
echo ""
echo "🔐 Примечание: dbt использует пользователя principalwater для полных прав на создание таблиц"
