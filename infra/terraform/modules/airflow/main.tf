terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.6.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.3"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
    }
  }
}

# --- Docker Network ---
resource "docker_network" "airflow_network" {
  count  = var.deploy_airflow ? 1 : 0
  name   = "airflow_network"
  driver = "bridge"
}

# --- PostgreSQL managed by external module postgres ---
# База данных PostgreSQL управляется модулем postgres

# --- Redis for Airflow Celery ---
resource "docker_image" "redis" {
  count = var.deploy_airflow ? 1 : 0
  name  = "redis:${var.redis_version}"
}

resource "docker_container" "redis" {
  count    = var.deploy_airflow ? 1 : 0
  name     = "airflow_redis"
  image    = docker_image.redis[0].name
  hostname = "airflow_redis"
  networks_advanced {
    name    = docker_network.airflow_network[0].name
    aliases = ["airflow_redis"]
  }
  restart = "unless-stopped"
  command = ["redis-server", "--appendonly", "yes"]
  volumes {
    host_path      = abspath(var.airflow_redis_data_path)
    container_path = "/data"
  }
  healthcheck {
    test     = ["CMD", "redis-cli", "ping"]
    interval = "10s"
    timeout  = "5s"
    retries  = 5
  }
}

# --- Airflow Webserver ---
resource "docker_image" "airflow" {
  count = var.deploy_airflow ? 1 : 0
  name  = "apache/airflow:${var.airflow_version}"
}

resource "docker_container" "airflow_webserver" {
  count    = var.deploy_airflow ? 1 : 0
  name     = "airflow_webserver"
  image    = docker_image.airflow[0].name
  hostname = "airflow_webserver"
  networks_advanced {
    name    = docker_network.airflow_network[0].name
    aliases = ["airflow_webserver"]
  }
  networks_advanced {
    name    = var.clickhouse_network_name
    aliases = ["airflow_webserver_ch"]
  }
  networks_advanced {
    name    = var.kafka_network_name
    aliases = ["airflow_webserver_kafka"]
  }
  ports {
    internal = 8080
    external = var.airflow_webserver_port
  }
  env = [
    "AIRFLOW__CORE__EXECUTOR=CeleryExecutor",
    "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=${var.airflow_postgres_connection_string}",
    "AIRFLOW__CELERY__RESULT_BACKEND=${var.airflow_postgres_connection_string}",
    "AIRFLOW__CELERY__BROKER_URL=redis://:@airflow_redis:6379/0",
    "AIRFLOW__CORE__FERNET_KEY=${var.airflow_fernet_key}",
    "AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION=True",
    "AIRFLOW__CORE__LOAD_EXAMPLES=False",
    "AIRFLOW__WEBSERVER__SECRET_KEY=${var.airflow_webserver_secret_key}",
    "AIRFLOW__CORE__DEFAULT_TIMEZONE=UTC",
    "AIRFLOW__CORE__SQL_ALCHEMY_POOL_SIZE=5",
    "AIRFLOW__CORE__SQL_ALCHEMY_MAX_OVERFLOW=10",
    "AIRFLOW__CORE__SQL_ALCHEMY_POOL_RECYCLE=1800",
    "AIRFLOW__CORE__SQL_ALCHEMY_POOL_PRE_PING=True",
    "AIRFLOW__CORE__ENABLE_XCOM_PICKLING=True"
  ]
  restart = "unless-stopped"
  volumes {
    host_path      = abspath(var.airflow_dags_path)
    container_path = "/opt/airflow/dags"
  }
  volumes {
    host_path      = abspath(var.airflow_logs_path)
    container_path = "/opt/airflow/logs"
  }
  volumes {
    host_path      = abspath(var.airflow_plugins_path)
    container_path = "/opt/airflow/plugins"
  }
  volumes {
    host_path      = abspath(var.airflow_config_path)
    container_path = "/opt/airflow/config"
  }
  depends_on = [
    # PostgreSQL управляется внешним модулем postgres
    docker_container.redis[0]
  ]
  healthcheck {
    test     = ["CMD", "curl", "--fail", "http://localhost:8080/health"]
    interval = "30s"
    timeout  = "10s"
    retries  = 5
    start_period = "60s"
  }
}

# --- Airflow Scheduler ---
resource "docker_container" "airflow_scheduler" {
  count    = var.deploy_airflow ? 1 : 0
  name     = "airflow_scheduler"
  image    = docker_image.airflow[0].name
  hostname = "airflow_scheduler"
  networks_advanced {
    name    = docker_network.airflow_network[0].name
    aliases = ["airflow_scheduler"]
  }
  networks_advanced {
    name    = var.clickhouse_network_name
    aliases = ["airflow_scheduler_ch"]
  }
  networks_advanced {
    name    = var.kafka_network_name
    aliases = ["airflow_scheduler_kafka"]
  }
  command = ["scheduler"]
  env = [
    "AIRFLOW__CORE__EXECUTOR=CeleryExecutor",
    "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=${var.airflow_postgres_connection_string}",
    "AIRFLOW__CELERY__RESULT_BACKEND=${var.airflow_postgres_connection_string}",
    "AIRFLOW__CELERY__BROKER_URL=redis://:@airflow_redis:6379/0",
    "AIRFLOW__CORE__FERNET_KEY=${var.airflow_fernet_key}",
    "AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION=True",
    "AIRFLOW__CORE__LOAD_EXAMPLES=False",
    "AIRFLOW__CORE__DEFAULT_TIMEZONE=UTC",
    "AIRFLOW__CORE__SQL_ALCHEMY_POOL_SIZE=5",
    "AIRFLOW__CORE__SQL_ALCHEMY_MAX_OVERFLOW=10",
    "AIRFLOW__CORE__SQL_ALCHEMY_POOL_RECYCLE=1800",
    "AIRFLOW__CORE__SQL_ALCHEMY_POOL_PRE_PING=True",
    "AIRFLOW__CORE__ENABLE_XCOM_PICKLING=True"
  ]
  restart = "unless-stopped"
  volumes {
    host_path      = abspath(var.airflow_dags_path)
    container_path = "/opt/airflow/dags"
  }
  volumes {
    host_path      = abspath(var.airflow_logs_path)
    container_path = "/opt/airflow/logs"
  }
  volumes {
    host_path      = abspath(var.airflow_plugins_path)
    container_path = "/opt/airflow/plugins"
  }
  volumes {
    host_path      = abspath(var.airflow_config_path)
    container_path = "/opt/airflow/config"
  }
  depends_on = [
    # PostgreSQL управляется внешним модулем postgres
    docker_container.redis[0]
  ]
}

# --- Airflow Worker ---
resource "docker_container" "airflow_worker" {
  count    = var.deploy_airflow ? 1 : 0
  name     = "airflow_worker"
  image    = docker_image.airflow[0].name
  hostname = "airflow_worker"
  networks_advanced {
    name    = docker_network.airflow_network[0].name
    aliases = ["airflow_worker"]
  }
  networks_advanced {
    name    = var.clickhouse_network_name
    aliases = ["airflow_worker_ch"]
  }
  networks_advanced {
    name    = var.kafka_network_name
    aliases = ["airflow_worker_kafka"]
  }
  command = ["celery", "worker"]
  env = [
    "AIRFLOW__CORE__EXECUTOR=CeleryExecutor",
    "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=${var.airflow_postgres_connection_string}",
    "AIRFLOW__CELERY__RESULT_BACKEND=${var.airflow_postgres_connection_string}",
    "AIRFLOW__CELERY__BROKER_URL=redis://:@airflow_redis:6379/0",
    "AIRFLOW__CORE__FERNET_KEY=${var.airflow_fernet_key}",
    "AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION=True",
    "AIRFLOW__CORE__LOAD_EXAMPLES=False",
    "AIRFLOW__CORE__DEFAULT_TIMEZONE=UTC",
    "AIRFLOW__CORE__ENABLE_XCOM_PICKLING=True"
  ]
  restart = "unless-stopped"
  volumes {
    host_path      = abspath(var.airflow_dags_path)
    container_path = "/opt/airflow/dags"
  }
  volumes {
    host_path      = abspath(var.airflow_logs_path)
    container_path = "/opt/airflow/logs"
  }
  volumes {
    host_path      = abspath(var.airflow_plugins_path)
    container_path = "/opt/airflow/plugins"
  }
  volumes {
    host_path      = abspath(var.airflow_config_path)
    container_path = "/opt/airflow/config"
  }
  depends_on = [
    # PostgreSQL управляется внешним модулем postgres
    docker_container.redis[0]
  ]
}

# --- Airflow Flower (Celery monitoring) ---
resource "docker_container" "airflow_flower" {
  count    = var.deploy_airflow ? 1 : 0
  name     = "airflow_flower"
  image    = docker_image.airflow[0].name
  hostname = "airflow_flower"
  networks_advanced {
    name    = docker_network.airflow_network[0].name
    aliases = ["airflow_flower"]
  }
  command = ["celery", "flower"]
  ports {
    internal = 5555
    external = var.airflow_flower_port
  }
  env = [
    "AIRFLOW__CORE__EXECUTOR=CeleryExecutor",
    "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=${var.airflow_postgres_connection_string}",
    "AIRFLOW__CELERY__RESULT_BACKEND=${var.airflow_postgres_connection_string}",
    "AIRFLOW__CELERY__BROKER_URL=redis://:@airflow_redis:6379/0",
    "AIRFLOW__CORE__FERNET_KEY=${var.airflow_fernet_key}"
  ]
  restart = "unless-stopped"
  depends_on = [
    # PostgreSQL управляется внешним модулем postgres
    docker_container.redis[0]
  ]
}

# --- Airflow Init ---
resource "null_resource" "airflow_init" {
  count = var.deploy_airflow ? 1 : 0
  
  provisioner "local-exec" {
    command = <<EOT
      echo "=== Инициализация Airflow ==="
      
      # Ожидание готовности PostgreSQL
      echo "Ожидание готовности PostgreSQL..."
      for i in {1..30}; do
        if docker exec postgres pg_isready -U postgres &> /dev/null; then
          echo "PostgreSQL готов"
          break
        fi
        echo "Попытка $i: Ждём готовности PostgreSQL..."
        sleep 3
      done
      
      # Ожидание готовности Redis
      echo "Ожидание готовности Redis..."
      for i in {1..30}; do
        if docker exec airflow_redis redis-cli ping &> /dev/null; then
          echo "Redis готов"
          break
        fi
        echo "Попытка $i: Ждём готовности Redis..."
        sleep 3
      done
      
      # Инициализация базы данных Airflow
      echo "Инициализация базы данных Airflow..."
      docker exec airflow_webserver airflow db init
      
      # Создание пользователя администратора
      echo "Создание пользователя администратора..."
      docker exec airflow_webserver airflow users create \
        --username ${var.airflow_admin_user} \
        --firstname Admin \
        --lastname User \
        --role Admin \
        --email admin@airflow.local \
        --password ${var.airflow_admin_password}
      
      # Создание подключений к ClickHouse и Kafka
      echo "Создание подключений к ClickHouse и Kafka..."
      
      # Подключение к ClickHouse
      docker exec airflow_webserver airflow connections add \
        'clickhouse_default' \
        --conn-type 'clickhouse' \
        --conn-host 'clickhouse-1' \
        --conn-port '9000' \
        --conn-login '${var.clickhouse_bi_user}' \
        --conn-password '${var.clickhouse_bi_password}' \
        --conn-extra '{"database": "default", "secure": false}'
      
      # Подключение к Kafka
      docker exec airflow_webserver airflow connections add \
        'kafka_default' \
        --conn-type 'kafka' \
        --conn-host 'kafka' \
        --conn-port '9092' \
        --conn-extra '{"bootstrap_servers": "kafka:9092", "security_protocol": "PLAINTEXT"}'
      
      echo "=== Инициализация Airflow завершена ==="
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
  
  depends_on = [
    docker_container.airflow_webserver[0],
    # PostgreSQL управляется внешним модулем postgres
    docker_container.redis[0]
  ]
  
  triggers = {
    admin_creds = "${var.airflow_admin_user}-${var.airflow_admin_password}"
    clickhouse_creds = "${var.clickhouse_bi_user}-${var.clickhouse_bi_password}"
  }
}

# --- Sample DAGs ---
resource "local_file" "sample_clickhouse_kafka_dag" {
  count    = var.deploy_airflow ? 1 : 0
  content  = <<-EOT
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.clickhouse.operators.clickhouse import ClickHouseOperator
from airflow.providers.kafka.producer import KafkaProducerOperator
import json

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'clickhouse_kafka_integration',
    default_args=default_args,
    description='Пример интеграции ClickHouse с Kafka',
    schedule_interval=timedelta(minutes=5),
    catchup=False,
    tags=['clickhouse', 'kafka', 'energy'],
)

def process_energy_data(**context):
    """Обработка энергетических данных"""
    # Здесь будет логика обработки данных
    return {"status": "success", "timestamp": datetime.now().isoformat()}

def send_to_kafka(**context):
    """Отправка данных в Kafka"""
    # Здесь будет логика отправки в Kafka
    return {"status": "sent_to_kafka"}

def load_to_clickhouse(**context):
    """Загрузка данных в ClickHouse"""
    # Здесь будет логика загрузки в ClickHouse
    return {"status": "loaded_to_clickhouse"}

process_task = PythonOperator(
    task_id='process_energy_data',
    python_callable=process_energy_data,
    dag=dag,
)

kafka_task = PythonOperator(
    task_id='send_to_kafka',
    python_callable=send_to_kafka,
    dag=dag,
)

clickhouse_task = PythonOperator(
    task_id='load_to_clickhouse',
    python_callable=load_to_clickhouse,
    dag=dag,
)

process_task >> kafka_task >> clickhouse_task
EOT
  filename = "${var.airflow_dags_path}/clickhouse_kafka_integration.py"
  
  depends_on = [null_resource.airflow_init]
}

# --- Environment file for Airflow ---
resource "local_file" "airflow_env_file" {
  count    = var.deploy_airflow ? 1 : 0
  content  = <<-EOT
# Airflow Configuration
AIRFLOW__CORE__EXECUTOR=CeleryExecutor
AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=${var.airflow_postgres_connection_string}
AIRFLOW__CELERY__RESULT_BACKEND=${var.airflow_postgres_connection_string}
AIRFLOW__CELERY__BROKER_URL=redis://:@airflow_redis:6379/0
AIRFLOW__CORE__FERNET_KEY=${var.airflow_fernet_key}
AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION=True
AIRFLOW__CORE__LOAD_EXAMPLES=False
AIRFLOW__WEBSERVER__SECRET_KEY=${var.airflow_webserver_secret_key}

# ClickHouse Connection
CLICKHOUSE_HOST=clickhouse-1
CLICKHOUSE_PORT=9000
CLICKHOUSE_USER=${var.clickhouse_bi_user}
CLICKHOUSE_PASSWORD=${var.clickhouse_bi_password}
CLICKHOUSE_DATABASE=default

# Kafka Connection
KAFKA_BOOTSTRAP_SERVERS=kafka:9092
KAFKA_TOPIC_1MIN=${var.kafka_topic_1min}
KAFKA_TOPIC_5MIN=${var.kafka_topic_5min}
EOT
  filename = "${var.airflow_config_path}/airflow.env"
  
  depends_on = [null_resource.airflow_init]
}
