#!/bin/bash

# Скрипт для запуска dbt с различными параметрами
# ClickHouse EnergyHub

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для логирования
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Проверка наличия dbt
check_dbt() {
    if ! command -v dbt &> /dev/null; then
        error "dbt не установлен. Установите dbt-core и dbt-clickhouse"
        exit 1
    fi
    
    log "dbt версия: $(dbt --version)"
}

# Проверка профиля
check_profile() {
    if ! dbt debug &> /dev/null; then
        error "Ошибка конфигурации профиля. Проверьте ~/.dbt/profiles.yml"
        exit 1
    fi
    
    success "Профиль dbt настроен корректно"
}

# Функция для запуска моделей
run_models() {
    local target=${1:-dev}
    local select=${2:-""}
    
    log "Запуск моделей dbt для target: $target"
    
    if [ -n "$select" ]; then
        log "Выбор моделей: $select"
        dbt run --target "$target" --select "$select"
    else
        dbt run --target "$target"
    fi
    
    success "Модели dbt успешно выполнены"
}

# Функция для запуска тестов
run_tests() {
    local target=${1:-dev}
    local select=${2:-""}
    
    log "Запуск тестов dbt для target: $target"
    
    if [ -n "$select" ]; then
        log "Выбор тестов: $select"
        dbt test --target "$target" --select "$select"
    else
        dbt test --target "$target"
    fi
    
    success "Тесты dbt успешно выполнены"
}

# Функция для генерации документации
generate_docs() {
    log "Генерация документации dbt"
    
    dbt docs generate
    success "Документация сгенерирована"
    
    if [ "$1" = "--serve" ]; then
        log "Запуск веб-сервера документации на http://localhost:8080"
        dbt docs serve --port 8080
    fi
}

# Функция для очистки
clean_project() {
    log "Очистка проекта dbt"
    
    dbt clean
    success "Проект очищен"
}

# Функция для установки зависимостей
install_deps() {
    log "Установка зависимостей dbt"
    
    dbt deps
    success "Зависимости установлены"
}

# Функция для DQ проверок
run_dq_checks() {
    local target=${1:-dev}
    
    log "Запуск DQ проверок для target: $target"
    
    # Запуск моделей с DQ проверками
    dbt run --target "$target" --select tag:dq_checked
    
    # Запуск тестов для DQ
    dbt test --target "$target" --select tag:dq_checked
    
    success "DQ проверки выполнены"
}

# Функция для показа справки
show_help() {
    echo "Использование: $0 [КОМАНДА] [ПАРАМЕТРЫ]"
    echo ""
    echo "Команды:"
    echo "  run [target] [select]     - Запуск моделей"
    echo "  test [target] [select]    - Запуск тестов"
    echo "  docs [--serve]            - Генерация документации"
    echo "  clean                     - Очистка проекта"
    echo "  deps                      - Установка зависимостей"
    echo "  dq [target]               - Запуск DQ проверок"
    echo "  help                      - Показать эту справку"
    echo ""
    echo "Примеры:"
    echo "  $0 run dev                    # Запуск всех моделей в dev"
    echo "  $0 run prod tag:ods          # Запуск ODS моделей в prod"
    echo "  $0 test dev stg_locations    # Тест конкретной модели"
    echo "  $0 dq prod                   # DQ проверки в prod"
    echo "  $0 docs --serve              # Генерация и запуск документации"
}

# Основная логика
main() {
    local command=${1:-help}
    
    case $command in
        "run")
            check_dbt
            check_profile
            run_models "${2:-dev}" "${3:-}"
            ;;
        "test")
            check_dbt
            check_profile
            run_tests "${2:-dev}" "${3:-}"
            ;;
        "docs")
            check_dbt
            check_profile
            generate_docs "$2"
            ;;
        "clean")
            check_dbt
            clean_project
            ;;
        "deps")
            check_dbt
            install_deps
            ;;
        "dq")
            check_dbt
            check_profile
            run_dq_checks "${2:-dev}"
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            error "Неизвестная команда: $command"
            show_help
            exit 1
            ;;
    esac
}

# Запуск основной функции
main "$@"
