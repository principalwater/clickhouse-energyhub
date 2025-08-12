#!/bin/bash

# Скрипт для загрузки переменных из Terraform.tfvars в переменные окружения
# Использование: source ./load_env.sh

echo "🔧 Загрузка переменных из Terraform.tfvars в окружение..."

# Проверяем наличие Terraform.tfvars
if [ ! -f "Terraform.tfvars" ]; then
    echo "❌ Файл Terraform.tfvars не найден"
    echo "💡 Убедитесь, что вы находитесь в директории infra/terraform"
    return 1
fi

# Функция для извлечения значения переменной из Terraform.tfvars
extract_var() {
    local var_name=$1
    local value=$(grep "^${var_name}[[:space:]]*=" Terraform.tfvars | sed 's/.*=[[:space:]]*"\([^"]*\)".*/\1/' | sed 's/.*=[[:space:]]*\([^[:space:]]*\).*/\1/')
    echo "$value"
}

# Загружаем переменные ClickHouse
echo "📊 Загрузка переменных ClickHouse..."
export SUPER_USER_NAME=$(extract_var "super_user_name")
export SUPER_USER_PASSWORD=$(extract_var "super_user_password")
export BI_USER_PASSWORD=$(extract_var "bi_user_password")
export ch_tcp_port=$(extract_var "ch_tcp_port")

# Загружаем переменные MinIO
echo "🗄️  Загрузка переменных MinIO..."
export MINIO_ROOT_USER=$(extract_var "minio_root_user")
export MINIO_ROOT_PASSWORD=$(extract_var "minio_root_password")

# Загружаем переменные SSH
echo "🔑 Загрузка переменных SSH..."
export REMOTE_SSH_USER=$(extract_var "remote_ssh_user")

# Загружаем переменные BI инфраструктуры
echo "📈 Загрузка переменных BI инфраструктуры..."
export PG_PASSWORD=$(extract_var "pg_password")
export SA_USERNAME=$(extract_var "sa_username")
export SA_PASSWORD=$(extract_var "sa_password")
export SUPERSET_SECRET_KEY=$(extract_var "superset_secret_key")

# Загружаем переменные Kafka
echo "📨 Загрузка переменных Kafka..."
export KAFKA_ADMIN_USER=$(extract_var "kafka_admin_user")
export KAFKA_ADMIN_PASSWORD=$(extract_var "kafka_admin_password")
export KAFKA_SSL_KEYSTORE_PASSWORD=$(extract_var "kafka_ssl_keystore_password")

# Загружаем переменные Airflow
echo "🪂 Загрузка переменных Airflow..."
export AIRFLOW_POSTGRES_PASSWORD=$(extract_var "airflow_postgres_password")
export AIRFLOW_ADMIN_USER=$(extract_var "airflow_admin_user")
export AIRFLOW_ADMIN_PASSWORD=$(extract_var "airflow_admin_password")
export AIRFLOW_FERNET_KEY=$(extract_var "airflow_fernet_key")
export AIRFLOW_WEBSERVER_SECRET_KEY=$(extract_var "airflow_webserver_secret_key")

# Загружаем переменные путей
echo "📁 Загрузка переменных путей..."
export CLICKHOUSE_BASE_PATH=$(extract_var "clickhouse_base_path")
export BI_POSTGRES_DATA_PATH=$(extract_var "bi_postgres_data_path")
export REMOTE_MINIO_PATH=$(extract_var "remote_minio_path")

# Загружаем переменные dbt
echo "🔧 Загрузка переменных dbt..."
export CLICKHOUSE_USER="$SUPER_USER_NAME"
export CLICKHOUSE_HOST="clickhouse-01"
export CLICKHOUSE_PORT=${ch_tcp_port:-9000}
export CLICKHOUSE_DATABASE="default"
export CLICKHOUSE_PASSWORD="$SUPER_USER_PASSWORD"

# Проверяем загрузку критических переменных
echo ""
echo "✅ Переменные окружения загружены:"
echo "   👤 ClickHouse Super User: $SUPER_USER_NAME"
echo "   🔑 ClickHouse Super Password: ${SUPER_USER_PASSWORD:0:3}***"
echo "   👤 ClickHouse BI User: $CLICKHOUSE_USER"
echo "   🔑 ClickHouse BI Password: ${BI_USER_PASSWORD:0:3}***"
echo "   🗄️  MinIO User: $MINIO_ROOT_USER"
echo "   🔑 MinIO Password: ${MINIO_ROOT_PASSWORD:0:3}***"
echo "   📊 Postgres Password: ${PG_PASSWORD:0:3}***"
echo "   🔑 SA Password: ${SA_PASSWORD:0:3}***"
echo "   📨 Kafka Admin Password: ${KAFKA_ADMIN_PASSWORD:0:3}***"
echo "   🪂 Airflow Admin Password: ${AIRFLOW_ADMIN_PASSWORD:0:3}***"

echo ""
echo "💡 Теперь вы можете использовать эти переменные в скриптах:"
echo "   echo \$CLICKHOUSE_USER"
echo "   echo \$BI_USER_PASSWORD"
echo "   echo \$SUPER_USER_PASSWORD"
echo ""
echo "💡 Для применения в текущей сессии выполните:"
echo "   source ./load_env.sh"
