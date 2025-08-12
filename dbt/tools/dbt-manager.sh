#!/bin/bash

# Основной скрипт управления dbt для ClickHouse EnergyHub
# Использование: ./dbt-manager.sh <команда> [опции]

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Функции для цветного вывода
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo -e "${PURPLE}=== $1 ===${NC}"; }

# Проверка директории
check_directory() {
    if [ ! -f "../dbt_project.yml" ]; then
        print_error "dbt_project.yml не найден. Запустите скрипт из директории dbt/tools"
        exit 1
    fi
}

# Загрузка переменных окружения
load_environment() {
    print_info "Загрузка переменных окружения..."
    
    # Пытаемся загрузить из Terraform.tfvars
    if [ -f "../../infra/terraform/Terraform.tfvars" ]; then
        cd ../../infra/terraform && source load_env.sh && cd - > /dev/null
        print_success "Переменные загружены из Terraform.tfvars"
    else
        print_warning "Terraform.tfvars не найден, используем переменные окружения"
        
        # Устанавливаем значения по умолчанию (используем super_user для полных прав)
        export CLICKHOUSE_USER=${CLICKHOUSE_USER:-"principalwater"}
        export CLICKHOUSE_HOST=${CLICKHOUSE_HOST:-"clickhouse-01"}
        export CLICKHOUSE_PORT=${CLICKHOUSE_PORT:-"9000"}
        export CLICKHOUSE_DATABASE=${CLICKHOUSE_DATABASE:-"default"}
        
        if [ -z "$CLICKHOUSE_PASSWORD" ]; then
            print_error "CLICKHOUSE_PASSWORD не установлена"
            print_info "Установите переменную окружения или используйте Terraform.tfvars"
            return 1
        fi
    fi
}

# Проверка окружения dbt
check_dbt_environment() {
    print_info "Проверка окружения dbt..."
    
    # Проверяем Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python3 не установлен"
        exit 1
    fi
    print_success "Python3 найден: $(python3 --version)"
    
    # Проверяем виртуальное окружение
    if [ ! -d "../dbt_env" ]; then
        print_error "Виртуальное окружение dbt_env не найдено"
        print_info "Запустите Terraform для создания dbt окружения"
        exit 1
    fi
    print_success "Виртуальное окружение dbt_env найдено"
    
    # Активируем окружение
    source ../dbt_env/bin/activate
    
    # Проверяем dbt
    if ! command -v dbt &> /dev/null; then
        print_error "dbt не установлен в виртуальном окружении"
        exit 1
    fi
    print_success "dbt найден: $(dbt --version)"
}

# Проверка подключения к ClickHouse
check_clickhouse_connection() {
    print_info "Проверка подключения к ClickHouse..."
    
    if ! command -v docker &> /dev/null; then
        print_warning "Docker не доступен для проверки ClickHouse"
        return 0
    fi
    
    if ! docker ps | grep -q "clickhouse-01"; then
        print_error "Контейнер clickhouse-01 не запущен"
        print_info "Запустите Terraform для развертывания ClickHouse"
        return 1
    fi
    
    print_success "Контейнер clickhouse-01 запущен"
    
    # Проверяем подключение
    if docker exec clickhouse-01 clickhouse-client --user "$CLICKHOUSE_USER" --password "$CLICKHOUSE_PASSWORD" --query "SELECT 1" 2>/dev/null; then
        print_success "Подключение к ClickHouse успешно"
        
        # Проверяем базу данных
        if docker exec clickhouse-01 clickhouse-client --user "$CLICKHOUSE_USER" --password "$CLICKHOUSE_PASSWORD" --query "USE $CLICKHOUSE_DATABASE; SELECT 'Database accessible' as status" 2>/dev/null; then
            print_success "База данных $CLICKHOUSE_DATABASE доступна"
        else
            print_error "База данных $CLICKHOUSE_DATABASE недоступна"
            return 1
        fi
    else
        print_error "Ошибка подключения к ClickHouse"
        return 1
    fi
}

# Проверка конфигурации dbt
check_dbt_config() {
    print_info "Проверка конфигурации dbt..."
    
    # Устанавливаем переменную окружения для профилей
    export DBT_PROFILES_DIR="$(cd .. && pwd)/profiles"
    
    # Проверяем наличие profiles.yml
    if [ ! -f "../profiles/profiles.yml" ]; then
        print_error "Файл profiles/profiles.yml не найден"
        print_info "Запустите Terraform для генерации profiles.yml"
        exit 1
    fi
    print_success "profiles/profiles.yml найден"
    
    # Проверяем подключение к базе данных
    if dbt debug; then
        print_success "Конфигурация dbt корректна"
    else
        print_error "Ошибка конфигурации dbt"
        exit 1
    fi
}

# Функция для запуска dbt команд
run_dbt_command() {
    local cmd="$1"
    local target="${2:-dev}"
    local model="$3"
    
    # Устанавливаем переменную окружения для профилей
    export DBT_PROFILES_DIR="$(cd .. && pwd)/profiles"
    
    print_info "Выполнение: dbt $cmd --target $target $model"
    
    if [ -n "$model" ]; then
        dbt "$cmd" --target "$target" --select "$model"
    else
        dbt "$cmd" --target "$target"
    fi
}

# Показать справку
show_help() {
    echo "Использование: $0 <команда> [опции]"
    echo ""
    echo "Команды:"
    echo "  setup          - Настройка и проверка окружения dbt"
    echo "  check          - Проверка подключения и конфигурации"
    echo "  deps           - Установка зависимостей dbt"
    echo "  run            - Запуск моделей dbt"
    echo "  test           - Запуск тестов dbt"
    echo "  compile        - Компиляция моделей dbt"
    echo "  docs           - Генерация документации dbt"
    echo "  serve          - Запуск веб-сервера документации"
    echo "  list           - Список доступных моделей"
    echo "  debug          - Отладочная информация"
    echo "  help           - Показать эту справку"
    echo ""
    echo "Примеры:"
    echo "  $0 setup                    # Настройка окружения"
    echo "  $0 deps                     # Установка зависимостей"
    echo "  $0 run                      # Запуск всех моделей"
    echo "  $0 run prod                 # Запуск моделей для prod"
    echo "  $0 test dev                 # Запуск тестов для dev"
    echo "  $0 docs                     # Генерация документации"
    echo "  $0 serve                    # Запуск веб-сервера"
}

# Основная логика
main() {
    local command="$1"
    local target="$2"
    local model="$3"
    
    check_directory
    
    case $command in
        "setup")
            print_header "Настройка окружения dbt"
            load_environment
            check_dbt_environment
            check_clickhouse_connection
            check_dbt_config
            print_success "Окружение dbt настроено и готово к работе!"
            ;;
        "check")
            print_header "Проверка окружения dbt"
            load_environment
            check_dbt_environment
            check_clickhouse_connection
            check_dbt_config
            print_success "Все проверки пройдены успешно!"
            ;;
        "deps")
            print_header "Установка зависимостей dbt"
            load_environment
            check_dbt_environment
            run_dbt_command "deps" "$target"
            print_success "Зависимости dbt установлены успешно!"
            ;;
        "run")
            print_header "Запуск моделей dbt"
            load_environment
            check_dbt_environment
            check_dbt_config
            run_dbt_command "run" "$target" "$model"
            print_success "Модели dbt запущены успешно!"
            ;;
        "test")
            print_header "Запуск тестов dbt"
            load_environment
            check_dbt_environment
            check_dbt_config
            run_dbt_command "test" "$target" "$model"
            print_success "Тесты dbt выполнены успешно!"
            ;;
        "compile")
            print_header "Компиляция моделей dbt"
            load_environment
            check_dbt_environment
            check_dbt_config
            run_dbt_command "compile" "$target" "$model"
            print_success "Модели dbt скомпилированы успешно!"
            ;;
        "docs")
            print_header "Генерация документации dbt"
            load_environment
            check_dbt_environment
            check_dbt_config
            run_dbt_command "docs" "$target" "generate"
            print_success "Документация dbt сгенерирована успешно!"
            ;;
        "serve")
            print_header "Запуск веб-сервера документации dbt"
            load_environment
            check_dbt_environment
            check_dbt_config
            print_info "Генерируем документацию..."
            dbt docs generate --target "${target:-dev}" --config-dir ../profiles
            print_info "Запускаем веб-сервер документации..."
            dbt docs serve --target "${target:-dev}" --config-dir ../profiles
            ;;
        "list")
            print_header "Список моделей dbt"
            load_environment
            check_dbt_environment
            check_dbt_config
            dbt list --target "${target:-dev}" --config-dir ../profiles
            ;;
        "debug")
            print_header "Отладочная информация"
            load_environment
            check_dbt_environment
            check_clickhouse_connection
            check_dbt_config
            print_info "Переменные окружения:"
            echo "  CLICKHOUSE_USER: $CLICKHOUSE_USER"
            echo "  CLICKHOUSE_HOST: $CLICKHOUSE_HOST"
            echo "  CLICKHOUSE_PORT: $CLICKHOUSE_PORT"
            echo "  CLICKHOUSE_DATABASE: $CLICKHOUSE_DATABASE"
            echo "  CLICKHOUSE_PASSWORD: ${CLICKHOUSE_PASSWORD:0:3}***"
            echo "  DBT_PROFILES_DIR: $DBT_PROFILES_DIR"
            ;;
        "help"|"--help"|"-h"|"")
            show_help
            ;;
        *)
            print_error "Неизвестная команда: $command"
            show_help
            exit 1
            ;;
    esac
}

# Запуск основной функции
main "$@"
