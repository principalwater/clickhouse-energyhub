#!/bin/bash

# Скрипт для генерации ключей Airflow
# Используется для создания Fernet ключа и секретного ключа веб-сервера

echo "=== Генерация ключей для Apache Airflow ==="
echo ""

# Проверяем наличие Python
if ! command -v python3 &> /dev/null; then
    echo "Ошибка: Python3 не найден. Установите Python3 для генерации Fernet ключа."
    exit 1
fi

# Проверяем наличие OpenSSL
if ! command -v openssl &> /dev/null; then
    echo "Ошибка: OpenSSL не найден. Установите OpenSSL для генерации секретного ключа."
    exit 1
fi

echo "1. Генерация Fernet ключа для шифрования..."
FERNET_KEY=$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")
echo "   Fernet ключ: $FERNET_KEY"
echo ""

echo "2. Генерация секретного ключа для веб-сервера..."
SECRET_KEY=$(openssl rand -base64 32)
echo "   Секретный ключ: $SECRET_KEY"
echo ""

echo "=== Скопируйте эти ключи в terraform.tfvars ==="
echo ""
echo "В файле terraform.tfvars добавьте:"
echo "deploy_airflow = true"
echo "airflow_fernet_key = \"$FERNET_KEY\""
echo "airflow_webserver_secret_key = \"$SECRET_KEY\""
echo "airflow_postgres_password = \"YOUR_AIRFLOW_POSTGRES_PASSWORD\""
echo "airflow_admin_password = \"YOUR_AIRFLOW_ADMIN_PASSWORD\""
echo ""
echo "=== Генерация завершена ==="
