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

# --- Создание необходимых директорий ---
resource "null_resource" "create_airflow_directories" {
  count = var.deploy_airflow ? 1 : 0
  
  provisioner "local-exec" {
    command = <<EOT
      echo "🔧 Создание директорий Airflow..."
      
      mkdir -p "${abspath(var.airflow_dags_path)}"
      mkdir -p "${abspath(var.airflow_logs_path)}"
      mkdir -p "${abspath(var.airflow_plugins_path)}"
      mkdir -p "${abspath(var.airflow_config_path)}"
      
      # Создание .env файла для Docker Compose совместимости
      echo "AIRFLOW_UID=50000" > ${dirname(var.airflow_dags_path)}/.env
      echo "AIRFLOW_GID=0" >> ${dirname(var.airflow_dags_path)}/.env
      
      echo "✅ Директории созданы успешно"
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

# --- Redis для Celery ---
resource "docker_image" "redis" {
  count = var.deploy_airflow ? 1 : 0
  name  = "redis:latest"
}

resource "docker_container" "redis" {
  count    = var.deploy_airflow ? 1 : 0
  name     = "redis"
  image    = docker_image.redis[0].name
  hostname = "redis"
  
  networks_advanced {
    name = docker_network.airflow_network[0].name
  }
  
  ports {
    internal = 6379
    external = 6379
  }
  
  healthcheck {
    test     = ["CMD", "redis-cli", "ping"]
    interval = "30s"
    timeout  = "30s"
    retries  = 50
    start_period = "30s"
  }
  
  restart = "always"
  
  depends_on = [null_resource.create_airflow_directories]
}

# --- Образ Airflow ---
resource "docker_image" "airflow" {
  count = var.deploy_airflow ? 1 : 0
  name  = "apache/airflow:${var.airflow_version}"
}

# --- Общая конфигурация для всех сервисов Airflow ---
locals {
  airflow_common_env = var.deploy_airflow ? [
    "AIRFLOW__CORE__EXECUTOR=CeleryExecutor",
    "AIRFLOW__CORE__AUTH_MANAGER=airflow.providers.fab.auth_manager.fab_auth_manager.FabAuthManager",
    "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=${var.airflow_postgres_connection_string}",
    "AIRFLOW__CELERY__RESULT_BACKEND=db+${var.airflow_postgres_connection_string}",
    "AIRFLOW__CELERY__BROKER_URL=redis://:@redis:6379/0",
    "AIRFLOW__CORE__FERNET_KEY=${var.airflow_fernet_key}",
    "AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION=true",
    "AIRFLOW__CORE__LOAD_EXAMPLES=false",
    "AIRFLOW__CORE__EXECUTION_API_SERVER_URL=http://airflow-api-server:8080/execution/",
    "AIRFLOW__SCHEDULER__ENABLE_HEALTH_CHECK=true",
    "_PIP_ADDITIONAL_REQUIREMENTS=",
    "AIRFLOW_CONFIG=/opt/airflow/config/airflow.cfg",
    "_AIRFLOW_DB_MIGRATE=true",
    "_AIRFLOW_WWW_USER_CREATE=true",
    "_AIRFLOW_WWW_USER_USERNAME=${var.airflow_admin_user}",
    "_AIRFLOW_WWW_USER_PASSWORD=${var.airflow_admin_password}"
  ] : []
  
  airflow_common_volumes = var.deploy_airflow ? [
    {
      host_path      = abspath(var.airflow_dags_path)
      container_path = "/opt/airflow/dags"
    },
    {
      host_path      = abspath(var.airflow_logs_path)
      container_path = "/opt/airflow/logs"
    },
    {
      host_path      = abspath(var.airflow_plugins_path)
      container_path = "/opt/airflow/plugins"
    },
    {
      host_path      = abspath(var.airflow_config_path)
      container_path = "/opt/airflow/config"
    }
  ] : []
}

# --- Airflow Init (одноразовая инициализация) ---
resource "null_resource" "airflow_init" {
  count = var.deploy_airflow ? 1 : 0
  
  provisioner "local-exec" {
    command = <<EOT
      echo "🚀 Запуск инициализации Airflow 3.0.4..."
      
      # Ожидание готовности PostgreSQL
      echo "⏳ Ожидание готовности PostgreSQL..."
      for i in {1..60}; do
        if docker exec postgres pg_isready -U postgres &> /dev/null 2>&1; then
          echo "✅ PostgreSQL готов"
          break
        fi
        echo "Попытка $i/60: Ждём PostgreSQL..."
        sleep 3
      done
      
      # Ожидание готовности Redis
      echo "⏳ Ожидание готовности Redis..."
      for i in {1..30}; do
        if docker exec redis redis-cli ping &> /dev/null 2>&1; then
          echo "✅ Redis готов"
          break
        fi
        echo "Попытка $i/30: Ждём Redis..."
        sleep 2
      done
      
      # Проверка и предоставление прав PostgreSQL
      echo "🔧 Предоставление прав PostgreSQL для Airflow..."
      docker exec postgres psql -U postgres -d airflow -c "
        GRANT ALL PRIVILEGES ON SCHEMA public TO airflow;
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO airflow;
        GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO airflow;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO airflow;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO airflow;
      " || echo "Права уже предоставлены или произошла ошибка"
      
      # Выполнение инициализации базы данных через временный контейнер
      echo "🔄 Запуск единократной инициализации Airflow..."
      docker run --rm \
        --name airflow-init-temp \
        --network ${docker_network.airflow_network[0].name} \
        --network ${var.postgres_network_name} \
        --user 50000:0 \
        -e AIRFLOW_UID=50000 \
        -e AIRFLOW__DATABASE__SQL_ALCHEMY_CONN='${var.airflow_postgres_connection_string}' \
        -e AIRFLOW__CORE__FERNET_KEY='${var.airflow_fernet_key}' \
        -e AIRFLOW__CORE__AUTH_MANAGER='airflow.providers.fab.auth_manager.fab_auth_manager.FabAuthManager' \
        -v "${abspath(var.airflow_dags_path)}:/opt/airflow/dags" \
        -v "${abspath(var.airflow_logs_path)}:/opt/airflow/logs" \
        -v "${abspath(var.airflow_plugins_path)}:/opt/airflow/plugins" \
        -v "${abspath(var.airflow_config_path)}:/opt/airflow/config" \
        apache/airflow:${var.airflow_version} \
        bash -c "
          echo '📁 Создание директорий...'
          mkdir -p /opt/airflow/{logs,dags,plugins,config}
          
          echo '🗃️ Выполнение миграции базы данных (однократно)...'
          airflow db migrate
          
          echo '👤 Создание администратора...'
          airflow users create \
            --username '${var.airflow_admin_user}' \
            --firstname 'Admin' \
            --lastname 'User' \
            --role 'Admin' \
            --email 'admin@example.com' \
            --password '${var.airflow_admin_password}' || echo 'Пользователь уже существует'
          
          echo '✅ Инициализация завершена успешно!'
        "
      
      echo "🎉 Airflow готов к запуску!"
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
  
  depends_on = [
    docker_container.redis[0],
    null_resource.create_airflow_directories[0]
  ]
  
  triggers = {
    airflow_version = var.airflow_version
    admin_user = var.airflow_admin_user
    postgres_connection = var.airflow_postgres_connection_string
    force_recreate = "v3.0.4-fixed-permissions-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  }
}

# --- Airflow API Server (Webserver) ---
resource "docker_container" "airflow_api_server" {
  count    = var.deploy_airflow ? 1 : 0
  name     = "airflow-api-server"
  image    = docker_image.airflow[0].name
  hostname = "airflow-api-server"
  
  networks_advanced {
    name = docker_network.airflow_network[0].name
  }
  networks_advanced {
    name = var.clickhouse_network_name
  }
  networks_advanced {
    name = var.kafka_network_name
  }
  networks_advanced {
    name = var.postgres_network_name
  }
  
  ports {
    internal = 8080
    external = var.airflow_webserver_port
  }
  
  command = ["api-server"]
  
  env = local.airflow_common_env
  
  user = "50000:0"
  
  dynamic "volumes" {
    for_each = local.airflow_common_volumes
    content {
      host_path      = volumes.value.host_path
      container_path = volumes.value.container_path
    }
  }
  
  healthcheck {
    test     = ["CMD", "curl", "--fail", "http://localhost:8080/api/v2/version"]
    interval = "30s"
    timeout  = "10s"
    retries  = 5
    start_period = "30s"
  }
  
  restart = "always"
  
  depends_on = [
    docker_container.redis[0],
    null_resource.airflow_init[0]
  ]
}

# --- Airflow Scheduler ---
resource "docker_container" "airflow_scheduler" {
  count    = var.deploy_airflow ? 1 : 0
  name     = "airflow-scheduler"
  image    = docker_image.airflow[0].name
  hostname = "airflow-scheduler"
  
  networks_advanced {
    name = docker_network.airflow_network[0].name
  }
  networks_advanced {
    name = var.clickhouse_network_name
  }
  networks_advanced {
    name = var.kafka_network_name
  }
  networks_advanced {
    name = var.postgres_network_name
  }
  
  command = ["scheduler"]
  
  env = local.airflow_common_env
  
  user = "50000:0"
  
  dynamic "volumes" {
    for_each = local.airflow_common_volumes
    content {
      host_path      = volumes.value.host_path
      container_path = volumes.value.container_path
    }
  }
  
  healthcheck {
    test = [
      "CMD-SHELL", 
      "airflow jobs check --job-type SchedulerJob --hostname \"$$HOSTNAME\" || exit 1"
    ]
    interval = "30s"
    timeout  = "10s"
    retries  = 5
    start_period = "60s"
  }
  
  restart = "always"
  
  depends_on = [
    docker_container.redis[0],
    null_resource.airflow_init[0]
  ]
}

# --- Airflow Worker ---
resource "docker_container" "airflow_worker" {
  count    = var.deploy_airflow ? 1 : 0
  name     = "airflow-worker"
  image    = docker_image.airflow[0].name
  hostname = "airflow-worker"
  
  networks_advanced {
    name = docker_network.airflow_network[0].name
  }
  networks_advanced {
    name = var.clickhouse_network_name
  }
  networks_advanced {
    name = var.kafka_network_name
  }
  networks_advanced {
    name = var.postgres_network_name
  }
  
  command = ["celery", "worker"]
  
  env = concat(local.airflow_common_env, [
    "DUMB_INIT_SETSID=0"
  ])
  
  user = "50000:0"
  
  dynamic "volumes" {
    for_each = local.airflow_common_volumes
    content {
      host_path      = volumes.value.host_path
      container_path = volumes.value.container_path
    }
  }
  
  healthcheck {
    test = [
      "CMD-SHELL",
      "celery -A airflow.providers.celery.executors.celery_executor.app inspect ping -d celery@$$HOSTNAME -t 10 || exit 1"
    ]
    interval = "30s"
    timeout  = "15s"
    retries  = 5
    start_period = "60s"
  }
  
  restart = "always"
  
  depends_on = [
    docker_container.redis[0],
    null_resource.airflow_init[0]
  ]
}

# --- Airflow Triggerer (Новое в Airflow 3.0) ---
resource "docker_container" "airflow_triggerer" {
  count    = var.deploy_airflow ? 1 : 0
  name     = "airflow-triggerer"
  image    = docker_image.airflow[0].name
  hostname = "airflow-triggerer"
  
  networks_advanced {
    name = docker_network.airflow_network[0].name
  }
  networks_advanced {
    name = var.postgres_network_name
  }
  
  command = ["triggerer"]
  
  env = local.airflow_common_env
  
  user = "50000:0"
  
  dynamic "volumes" {
    for_each = local.airflow_common_volumes
    content {
      host_path      = volumes.value.host_path
      container_path = volumes.value.container_path
    }
  }
  
  healthcheck {
    test = [
      "CMD-SHELL",
      "pgrep -f 'airflow triggerer' || exit 1"
    ]
    interval = "30s"
    timeout  = "10s"
    retries  = 5
    start_period = "60s"
  }
  
  restart = "always"
  
  depends_on = [
    docker_container.redis[0],
    null_resource.airflow_init[0]
  ]
}

# --- Airflow DAG Processor (Новое в Airflow 3.0) ---
resource "docker_container" "airflow_dag_processor" {
  count    = var.deploy_airflow ? 1 : 0
  name     = "airflow-dag-processor"
  image    = docker_image.airflow[0].name
  hostname = "airflow-dag-processor"
  
  networks_advanced {
    name = docker_network.airflow_network[0].name
  }
  networks_advanced {
    name = var.postgres_network_name
  }
  
  command = ["dag-processor"]
  
  env = local.airflow_common_env
  
  user = "50000:0"
  
  dynamic "volumes" {
    for_each = local.airflow_common_volumes
    content {
      host_path      = volumes.value.host_path
      container_path = volumes.value.container_path
    }
  }
  
  healthcheck {
    test = [
      "CMD-SHELL", 
      "pgrep -f 'airflow dag-processor' || exit 1"
    ]
    interval = "30s"
    timeout  = "10s"
    retries  = 5
    start_period = "60s"
  }
  
  restart = "always"
  
  depends_on = [
    docker_container.redis[0],
    null_resource.airflow_init[0]
  ]
}

# --- Airflow Flower (опционально) ---
resource "docker_container" "airflow_flower" {
  count    = var.deploy_airflow && var.enable_flower ? 1 : 0
  name     = "airflow-flower"
  image    = docker_image.airflow[0].name
  hostname = "airflow-flower"
  
  networks_advanced {
    name = docker_network.airflow_network[0].name
  }
  
  ports {
    internal = 5555
    external = var.airflow_flower_port
  }
  
  command = ["celery", "flower"]
  
  env = local.airflow_common_env
  
  user = "50000:0"
  
  dynamic "volumes" {
    for_each = local.airflow_common_volumes
    content {
      host_path      = volumes.value.host_path
      container_path = volumes.value.container_path
    }
  }
  
  healthcheck {
    test = ["CMD", "curl", "--fail", "http://localhost:5555/"]
    interval = "30s"
    timeout  = "10s"
    retries  = 5
    start_period = "30s"
  }
  
  restart = "always"
  
  depends_on = [
    docker_container.redis[0],
    null_resource.airflow_init[0]
  ]
}

# --- Настройка подключений после запуска ---
resource "null_resource" "setup_airflow_connections" {
  count = var.deploy_airflow ? 1 : 0
  
  provisioner "local-exec" {
    command = <<EOT
      echo "🔧 Ожидание готовности API сервера..."
      
      for i in {1..60}; do
        if curl -s http://localhost:${var.airflow_webserver_port}/health > /dev/null; then
          echo "✅ API сервер готов"
          break
        fi
        echo "⏳ Ожидание API сервера... ($i/60)"
        sleep 5
      done
      
      # Создание подключений
      docker exec airflow-api-server airflow connections add \
        'clickhouse_default' \
        --conn-type 'http' \
        --conn-host 'clickhouse-1' \
        --conn-port '8123' \
        --conn-login '${var.clickhouse_bi_user}' \
        --conn-password '${var.clickhouse_bi_password}' \
        --conn-extra '{"database": "default"}' || echo "Подключение ClickHouse уже существует"
      
      docker exec airflow-api-server airflow connections add \
        'kafka_default' \
        --conn-type 'kafka' \
        --conn-extra '{"bootstrap.servers": "kafka:9092"}' || echo "Подключение Kafka уже существует"
      
      echo "✅ Настройка подключений завершена"
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
  
  depends_on = [
    docker_container.airflow_api_server[0]
  ]
  
  triggers = {
    api_server_config = docker_container.airflow_api_server[0].id
  }
}

# --- Создание примера DAG ---
resource "local_file" "sample_dag" {
  count = var.deploy_airflow ? 1 : 0
  
  content = <<EOF
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator

# Определение параметров DAG
default_args = {
    'owner': 'energy-hub',
    'depends_on_past': False,
    'start_date': datetime(2025, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# Создание DAG
dag = DAG(
    'energy_data_pipeline',
    default_args=default_args,
    description='Pipeline обработки энергетических данных',
    schedule=timedelta(hours=1),
    catchup=False,
    tags=['energy', 'kafka', 'clickhouse'],
)

def extract_data(**context):
    """Извлечение данных из источников"""
    print("🔄 Извлечение данных из Kafka...")
    # Здесь будет логика извлечения данных из Kafka
    return "Data extracted successfully"

def transform_data(**context):
    """Трансформация данных"""
    print("🔄 Трансформация данных...")
    # Здесь будет логика трансформации данных
    return "Data transformed successfully"

def load_data(**context):
    """Загрузка данных в ClickHouse"""
    print("🔄 Загрузка данных в ClickHouse...")
    # Здесь будет логика загрузки данных в ClickHouse
    return "Data loaded successfully"

# Определение задач
extract_task = PythonOperator(
    task_id='extract_data',
    python_callable=extract_data,
    dag=dag,
)

transform_task = PythonOperator(
    task_id='transform_data',
    python_callable=transform_data,
    dag=dag,
)

load_task = PythonOperator(
    task_id='load_data',
    python_callable=load_data,
    dag=dag,
)

health_check = BashOperator(
    task_id='health_check',
    bash_command='echo "✅ Energy Hub pipeline is healthy"',
    dag=dag,
)

# Определение зависимостей задач
extract_task >> transform_task >> load_task >> health_check
EOF
  
  filename = "${var.airflow_dags_path}/energy_data_pipeline.py"
  
  depends_on = [null_resource.create_airflow_directories]
}