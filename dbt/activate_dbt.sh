#!/bin/bash
# Скрипт для активации dbt окружения
cd /Users/principalwater/Documents/git/clickhouse-energyhub/dbt
source dbt_env/bin/activate
echo "dbt environment activated"
echo "dbt version: $(dbt --version)"
echo "Available commands:"
echo "  dbt run - запуск моделей"
echo "  dbt test - запуск тестов"
echo "  dbt docs generate - генерация документации"
echo "  dbt docs serve - запуск документации"
