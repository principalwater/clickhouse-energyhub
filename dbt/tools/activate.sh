#!/bin/bash

# Скрипт для быстрой активации dbt окружения
# Использование: source ./activate.sh

echo "🔧 Активация dbt окружения..."

# Переходим в корневую директорию dbt
cd "$(dirname "$0")/.."

# Устанавливаем переменную окружения для профилей
export DBT_PROFILES_DIR="$(pwd)/profiles"

# Активируем виртуальное окружение
if [ -d "dbt_env" ]; then
    source dbt_env/bin/activate
    echo "✅ Виртуальное окружение dbt_env активировано"
else
    echo "❌ Виртуальное окружение dbt_env не найдено"
    echo "💡 Запустите Terraform для создания dbt окружения"
    return 1
fi

# Проверяем dbt
if command -v dbt &> /dev/null; then
    echo "✅ dbt доступен: $(dbt --version)"
else
    echo "❌ dbt недоступен в PATH"
    return 1
fi

echo ""
echo "🎉 dbt окружение активировано!"
echo "📁 Профили: $DBT_PROFILES_DIR"
echo ""
echo "💡 Доступные команды:"
echo "  dbt run --config-dir profiles     # Запуск моделей"
echo "  dbt test --config-dir profiles    # Запуск тестов"
echo "  dbt docs generate --config-dir profiles  # Генерация документации"
echo "  dbt docs serve --config-dir profiles     # Запуск документации"
echo "  dbt debug --config-dir profiles   # Проверка конфигурации"
echo "  dbt compile --config-dir profiles # Компиляция моделей"
echo "  dbt list --config-dir profiles   # Список моделей"
echo ""
echo "💡 Или используйте единый менеджер:"
echo "  ./tools/dbt-manager.sh help"
echo ""
echo "🔐 Примечание: dbt использует пользователя principalwater для полных прав на создание таблиц"
