###############################################################################
# Root Terraform file for deploying the ClickHouse EnergyHub
###############################################################################

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.6.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "6.4.0"
    }
  }
}

# --- Providers ---
# Note: Providers are defined in the root and passed down to modules implicitly.
provider "docker" {}

provider "docker" {
  alias = "remote_host"
  host  = var.storage_type == "local_storage" ? "unix:///var/run/docker.sock" : "ssh://${var.remote_ssh_user}@${var.remote_host_name}"
}

provider "aws" {
  alias      = "remote_backup"
  access_key = var.minio_root_user
  secret_key = var.minio_root_password
  region     = "us-east-1"
  endpoints {
    s3 = "http://${var.remote_host_name}:${var.remote_minio_port}"
  }
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

provider "aws" {
  alias      = "local_storage"
  access_key = var.minio_root_user
  secret_key = var.minio_root_password
  region     = "us-east-1"
  endpoints {
    s3 = "http://localhost:${var.local_minio_port}"
  }
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

# --- Modules ---

module "clickhouse_cluster" {
  source = "./modules/clickhouse-cluster"

  providers = {
    docker.remote_host = docker.remote_host
    aws.remote_backup  = aws.remote_backup
    aws.local_storage  = aws.local_storage
  }

  # Pass all necessary variables to the module
  clickhouse_base_path    = var.clickhouse_base_path
  memory_limit            = var.memory_limit
  super_user_name         = var.super_user_name
  bi_user_name            = var.bi_user_name
  super_user_password     = var.super_user_password
  bi_user_password        = var.bi_user_password
  ch_version              = var.ch_version
  chk_version             = var.chk_version
  minio_version           = var.minio_version
  ch_uid                  = var.ch_uid
  ch_gid                  = var.ch_gid
  use_standard_ports      = var.use_standard_ports
  ch_http_port            = var.ch_http_port
  ch_tcp_port             = var.ch_tcp_port
  ch_replication_port     = var.ch_replication_port
  minio_root_user         = var.minio_root_user
  minio_root_password     = var.minio_root_password
  remote_ssh_user         = var.remote_ssh_user
  ssh_private_key_path    = var.ssh_private_key_path
  local_minio_port        = var.local_minio_port
  remote_minio_port       = var.remote_minio_port
  storage_type            = var.storage_type
  local_minio_path        = var.local_minio_path
  remote_minio_path       = var.remote_minio_path
  local_backup_minio_path = var.local_backup_minio_path
  remote_host_name        = var.remote_host_name
  bucket_backup           = var.bucket_backup
  bucket_storage          = var.bucket_storage
  local_backup_minio_port = var.local_backup_minio_port
}

module "postgres" {
  source = "./modules/postgres"

  # Основные настройки
  enable_postgres             = var.deploy_metabase || var.deploy_superset || var.deploy_airflow
  postgres_version            = var.postgres_version
  postgres_data_path          = var.bi_postgres_data_path
  postgres_superuser_password = var.pg_password
  pg_password                 = var.pg_password
  postgres_restore_enabled    = var.postgres_restore_enabled

  # Флаги сервисов
  enable_metabase = var.deploy_metabase
  enable_superset = var.deploy_superset
  enable_airflow  = var.deploy_airflow

  # Metabase настройки
  metabase_pg_user     = var.metabase_pg_user
  metabase_pg_password = var.pg_password
  metabase_pg_db       = var.metabase_pg_db

  # Superset настройки
  superset_pg_user     = var.superset_pg_user
  superset_pg_password = var.pg_password
  superset_pg_db       = var.superset_pg_db

  # Airflow настройки
  airflow_pg_user     = var.airflow_postgres_user
  airflow_pg_password = var.airflow_postgres_password
  airflow_pg_db       = var.airflow_postgres_db

  depends_on = [module.clickhouse_cluster]
}

module "bi_infra" {
  source = "./modules/bi-infra"

  # Flags to enable/disable BI tools
  deploy_metabase = var.deploy_metabase
  deploy_superset = var.deploy_superset

  # Versions
  postgres_version = var.postgres_version
  metabase_version = var.metabase_version
  superset_version = var.superset_version

  # Ports
  metabase_port = var.metabase_port
  superset_port = var.superset_port

  # Passwords and Secrets
  pg_password         = var.pg_password
  sa_password         = var.sa_password
  superset_secret_key = var.superset_secret_key
  bi_password         = var.bi_user_password # Use the main CH BI user password

  # Usernames
  sa_username = var.sa_username
  bi_user     = var.bi_user_name # Use the main CH BI username

  # Postgres settings (используем модуль postgres)
  postgres_container_name = module.postgres.postgres_container_name
  postgres_network_name   = module.postgres.postgres_network_name

  # Metabase settings
  metabase_site_name = var.metabase_site_name

  # User lists (defaults to empty list)
  metabase_local_users = var.metabase_local_users
  superset_local_users = var.superset_local_users

  # Metabase settings
  metabase_pg_user     = var.metabase_pg_user
  metabase_pg_password = var.pg_password
  metabase_pg_db       = var.metabase_pg_db
  metabase_sa_username = var.sa_username
  metabase_sa_password = var.sa_password
  metabase_bi_username = var.bi_user_name
  metabase_bi_password = var.bi_user_password

  # Superset settings
  superset_pg_user     = var.superset_pg_user
  superset_pg_password = var.pg_password
  superset_pg_db       = var.superset_pg_db
  superset_sa_username = var.sa_username
  superset_sa_password = var.sa_password
  superset_bi_username = var.bi_user_name
  superset_bi_password = var.bi_user_password

  # PostgreSQL superuser password
  postgres_superuser_password = var.pg_password

  # Postgres restore enable flag
  postgres_restore_enabled = var.postgres_restore_enabled

  # Airflow settings (для поддержки в PostgreSQL)
  airflow_enabled     = var.deploy_airflow
  airflow_pg_user     = var.airflow_postgres_user
  airflow_pg_password = var.airflow_postgres_password
  airflow_pg_db       = var.airflow_postgres_db

  # Fallback passwords for local logic (используем те же переменные, что и выше)
  # metabase_pg_password и superset_pg_password уже переданы выше как var.pg_password

  depends_on = [module.clickhouse_cluster, module.postgres]
}

module "monitoring" {
  source = "./modules/monitoring"

  portainer_version    = var.portainer_version
  portainer_https_port = var.portainer_https_port
  portainer_agent_port = var.portainer_agent_port

  depends_on = [module.clickhouse_cluster]
}

module "kafka" {
  source = "./modules/kafka"

  kafka_version               = var.kafka_version
  docker_network_name         = module.clickhouse_cluster.network_name
  topic_1min                  = var.topic_1min
  topic_5min                  = var.topic_5min
  kafka_admin_user            = var.kafka_admin_user
  kafka_admin_password        = var.kafka_admin_password
  kafka_ssl_keystore_password = var.kafka_ssl_keystore_password
  secrets_path                = abspath("../secrets")
  enable_kafka_acl            = false

  depends_on = [module.clickhouse_cluster]
}

module "airflow" {
  source = "./modules/airflow"

  providers = {
    docker = docker
  }

  # Основные настройки
  deploy_airflow       = var.deploy_airflow
  enable_flower        = false
  disable_healthchecks = false

  # Версии
  airflow_version = var.airflow_version
  redis_version   = var.redis_version

  # Порты
  airflow_webserver_port = var.airflow_webserver_port
  airflow_flower_port    = var.airflow_flower_port

  # PostgreSQL (используем модуль postgres)
  airflow_postgres_connection_string = module.postgres.airflow_db_connection_string
  postgres_network_name              = module.postgres.postgres_network_name

  # Redis
  airflow_redis_data_path = var.airflow_redis_data_path

  # Airflow
  airflow_admin_user           = var.airflow_admin_user
  airflow_admin_password       = var.airflow_admin_password
  airflow_fernet_key           = var.airflow_fernet_key
  airflow_webserver_secret_key = var.airflow_webserver_secret_key

  # Пути к директориям
  airflow_dags_path    = var.airflow_dags_path
  airflow_logs_path    = var.airflow_logs_path
  airflow_plugins_path = var.airflow_plugins_path
  airflow_config_path  = var.airflow_config_path
  scripts_path         = var.scripts_path

  # Интеграция с ClickHouse
  clickhouse_network_name = module.clickhouse_cluster.network_name
  clickhouse_bi_user      = var.bi_user_name
  clickhouse_bi_password  = var.bi_user_password

  # Интеграция с Kafka
  kafka_network_name = module.kafka.network_name
  kafka_topic_1min   = var.topic_1min
  kafka_topic_5min   = var.topic_5min

  depends_on = [module.clickhouse_cluster, module.kafka, module.postgres]
}

module "dbt" {
  source = "./modules/dbt"

  # Основные настройки dbt
  dbt_project_name = "clickhouse_energyhub"
  dbt_version      = var.dbt_version
  dbt_core_version = var.dbt_core_version
  dbt_port         = var.dbt_port
  dbt_host         = "localhost"
  dbt_base_path    = var.dbt_base_path

  # Подключение к ClickHouse (используем super_user для полных прав)
  clickhouse_host     = "clickhouse-01"
  clickhouse_port     = 9000
  clickhouse_database = "default"
  clickhouse_user     = var.super_user_name
  clickhouse_password = var.super_user_password

  # Учетные данные суперпользователя для создания объектов
  super_user_name     = var.super_user_name
  super_user_password = var.super_user_password

  depends_on = [module.clickhouse_cluster]

  count = var.deploy_dbt ? 1 : 0
}
