#!/bin/bash

# dbt runner script for ClickHouse EnergyHub
# Usage: ./run_dbt.sh <command> [target] [model]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
TARGET=${2:-"dev"}
MODEL=${3:-""}

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if dbt environment is activated
check_dbt_env() {
    if ! command -v dbt &> /dev/null; then
        print_error "dbt not found. Please activate the dbt environment first:"
        echo "source dbt_env/bin/activate"
        exit 1
    fi
}

# Check if we're in the right directory
check_directory() {
    if [ ! -f "dbt_project.yml" ]; then
        print_error "dbt_project.yml not found. Please run this script from the dbt directory."
        exit 1
    fi
}

# Function to run dbt command
run_dbt() {
    local cmd="$1"
    local target="$2"
    local model="$3"
    
    print_info "Running: dbt $cmd --target $target $model"
    
    if [ -n "$model" ]; then
        dbt "$cmd" --target "$target" --select "$model"
    else
        dbt "$cmd" --target "$target"
    fi
}

# Main script logic
main() {
    local command="$1"
    
    check_directory
    check_dbt_env
    
    case $command in
        "run")
            print_info "Running dbt models for target: $TARGET"
            run_dbt "run" "$TARGET" "$MODEL"
            print_success "dbt run completed successfully!"
            ;;
        "test")
            print_info "Running dbt tests for target: $TARGET"
            run_dbt "test" "$TARGET" "$MODEL"
            print_success "dbt tests completed successfully!"
            ;;
        "compile")
            print_info "Compiling dbt models for target: $TARGET"
            run_dbt "compile" "$TARGET" "$MODEL"
            print_success "dbt compile completed successfully!"
            ;;
        "docs")
            if [ "$MODEL" = "--serve" ]; then
                print_info "Generating and serving dbt documentation"
                dbt docs generate --target "$TARGET"
                dbt docs serve --target "$TARGET"
            else
                print_info "Generating dbt documentation for target: $TARGET"
                run_dbt "docs" "$TARGET" "generate"
                print_success "dbt docs generated successfully!"
            fi
            ;;
        "seed")
            print_info "Running dbt seed for target: $TARGET"
            run_dbt "seed" "$TARGET" "$MODEL"
            print_success "dbt seed completed successfully!"
            ;;
        "snapshot")
            print_info "Running dbt snapshot for target: $TARGET"
            run_dbt "snapshot" "$TARGET" "$MODEL"
            print_success "dbt snapshot completed successfully!"
            ;;
        "list")
            print_info "Listing dbt models for target: $TARGET"
            run_dbt "list" "$TARGET" "$MODEL"
            ;;
        "debug")
            print_info "Running dbt debug for target: $TARGET"
            run_dbt "debug" "$TARGET"
            ;;
        "clean")
            print_info "Cleaning dbt artifacts"
            dbt clean
            print_success "dbt clean completed successfully!"
            ;;
        "deps")
            print_info "Installing dbt dependencies"
            dbt deps
            print_success "dbt deps completed successfully!"
            ;;
        "help"|"--help"|"-h")
            echo "Usage: $0 <command> [target] [model]"
            echo ""
            echo "Commands:"
            echo "  run       - Run dbt models"
            echo "  test      - Run dbt tests"
            echo "  compile   - Compile dbt models"
            echo "  docs      - Generate dbt documentation"
            echo "  seed      - Run dbt seed"
            echo "  snapshot  - Run dbt snapshot"
            echo "  list      - List dbt models"
            echo "  debug     - Run dbt debug"
            echo "  clean     - Clean dbt artifacts"
            echo "  deps      - Install dbt dependencies"
            echo "  help      - Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 run dev                    # Run all models in dev"
            echo "  $0 run prod                   # Run all models in prod"
            echo "  $0 run dev stg_locations      # Run specific model in dev"
            echo "  $0 test dev                   # Run all tests in dev"
            echo "  $0 docs --serve              # Generate and serve docs"
            echo ""
            echo "Targets: dev, prod, test"
            ;;
        *)
            print_error "Unknown command: $command"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Check if command is provided
if [ $# -eq 0 ]; then
    print_error "No command provided"
    echo "Use '$0 help' for usage information"
    exit 1
fi

# Run main function
main "$@"
