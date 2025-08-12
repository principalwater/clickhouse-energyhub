#!/bin/bash

# Скрипт для быстрого развертывания ClickHouse EnergyHub
# Использование: ./deploy.sh [storage_type]
# storage_type: local_storage (по умолчанию) или s3_storage

set -e

echo "🚀 Запуск развертывания ClickHouse EnergyHub..."

# Проверяем наличие Terraform
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform не установлен. Установите Terraform и попробуйте снова."
    exit 1
fi

# Проверяем наличие Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker не установлен. Установите Docker и попробуйте снова."
    exit 1
fi

# Проверяем наличие Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 не установлен. Установите Python3 и попробуйте снова."
    exit 1
fi

# Определяем тип хранилища
STORAGE_TYPE=${1:-local_storage}
echo "📦 Тип хранилища: $STORAGE_TYPE"

# Переходим в директорию Terraform
cd infra/terraform

# Загружаем учетные данные суперпользователя из Terraform.tfvars
echo "🔐 Загрузка учетных данных суперпользователя из Terraform.tfvars..."
if [ -f "Terraform.tfvars" ]; then
    SUPER_USER=$(grep "super_user_name" Terraform.tfvars | awk -F'=' '{print $2}' | tr -d ' "')
    SUPER_PASSWORD=$(grep "super_user_password" Terraform.tfvars | awk -F'=' '{print $2}' | tr -d ' "')
    
    if [ -n "$SUPER_USER" ] && [ -n "$SUPER_PASSWORD" ]; then
        export SUPER_USER
        export SUPER_PASSWORD
        echo "✅ Учетные данные загружены: $SUPER_USER"
    else
        echo "❌ Не удалось загрузить учетные данные из Terraform.tfvars"
        exit 1
    fi
else
    echo "❌ Файл Terraform.tfvars не найден"
    exit 1
fi

echo "🔧 Инициализация Terraform..."
terraform init

echo "📋 Планирование развертывания..."
terraform plan -var="storage_type=$STORAGE_TYPE"

echo "❓ Продолжить развертывание? (y/N)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "🚀 Запуск развертывания..."
    terraform apply -var="storage_type=$STORAGE_TYPE" -auto-approve
    
    echo "✅ Развертывание завершено!"
    echo ""
    echo "📊 Информация о развернутых ресурсах:"
    terraform output
    
    echo ""
    echo "🔍 Для проверки dbt выполните:"
    echo "  cd dbt/tools"
    echo "  ./dbt-manager.sh setup"
    echo "  ./dbt-manager.sh check"
    
    echo ""
    echo "🌐 Для доступа к ClickHouse:"
    echo "  clickhouse-client -h localhost -p 9000 -u bi_user -p bi_password"
    
    echo ""
    echo "📚 Для документации dbt:"
    echo "  cd dbt/tools"
    echo "  source ./activate.sh"
    echo "  dbt docs generate --config-dir ../profiles"
    echo "  dbt docs serve --config-dir ../profiles"
    
    echo ""
    echo "🚀 Быстрый старт dbt:"
    echo "  cd dbt/tools"
    echo "  ./dbt-manager.sh setup"
    echo "  ./dbt-manager.sh run"
    
    echo ""
    echo "🗄️ База данных otus_default создана автоматически в ClickHouse"
    echo "   - Проверьте её: cd dbt/tools && ./dbt-manager.sh check"
    echo "   - Диагностика: cd dbt/tools && ./diagnose.sh"
    
    echo ""
    echo "💡 Основные команды dbt:"
    echo "  cd dbt/tools && ./dbt-manager.sh help          # Справка по всем командам"
    echo "  cd dbt/tools && ./dbt-manager.sh run           # Запуск моделей"
    echo "  cd dbt/tools && ./dbt-manager.sh test          # Запуск тестов"
    echo "  cd dbt/tools && ./dbt-manager.sh docs          # Генерация документации"
    echo "  cd dbt/tools && ./dbt-manager.sh serve         # Запуск веб-сервера документации"
    
    echo ""
    echo "📊 Настройка BI-инструментов:"
    echo "  🌐 Metabase: http://localhost:3000"
    echo "  🌐 Superset: http://localhost:8088"
    echo "  📖 Руководство по настройке подключений к ClickHouse:"
    echo "     docs/BI_CLICKHOUSE_SETUP.md"
    echo ""
    echo "🔧 Устранение неполадок:"
    echo "  cd dbt/tools && ./diagnose.sh                  # Диагностика окружения"
    echo "  cd dbt/tools && ./dbt-manager.sh debug         # Отладочная информация"
    
else
    echo "❌ Развертывание отменено."
    exit 0
fi
