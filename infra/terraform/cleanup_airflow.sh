#!/bin/bash

# Скрипт для очистки контейнеров и сети Airflow
# Используется при зависании на фазе setup_airflow_connections

echo "🧹 Очистка Airflow контейнеров и сети..."

# Останавливаем и удаляем контейнеры Airflow
echo "📦 Остановка и удаление контейнеров Airflow..."

# Останавливаем контейнеры (если запущены)
docker stop airflow-webserver airflow-scheduler airflow-worker airflow-api-server airflow-triggerer 2>/dev/null || true
docker stop airflow-init-temp 2>/dev/null || true

# Удаляем контейнеры
docker rm airflow-webserver airflow-scheduler airflow-worker airflow-api-server airflow-triggerer 2>/dev/null || true
docker rm airflow-init-temp 2>/dev/null || true

# Удаляем сеть Airflow
echo "🌐 Удаление сети Airflow..."
docker network rm airflow_network 2>/dev/null || true

# Очищаем тома и удаляем образы (опционально - раскомментируйте если нужно полная очистка)
# echo "🗂️ Очистка томов Airflow..."
# sudo rm -rf ../../volumes/airflow/logs/*
# sudo rm -rf ../../volumes/airflow/plugins/*
# sudo rm -rf ../../volumes/airflow/config/*
# docker rmi apache/airflow:2.8.1 2>/dev/null || true
# docker rmi apache/airflow:latest 2>/dev/null || true

echo "✅ Очистка завершена!"
echo ""
echo "Теперь можно запустить deploy.sh заново:"
echo "cd ../../ && ./deploy.sh"
