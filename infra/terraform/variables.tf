variable "clickhouse_base_path" {
  description = "Путь к данным и конфигурациям ClickHouse."
  type        = string
  default     = "../../volumes/clickhouse"
}

variable "memory_limit" {
  type    = number
  default = 12884901888 # 12 * 1024 * 1024 * 1024
}

variable "super_user_name" {
  description = "Основной пользователь ClickHouse (например, your_awesome_user)"
  type        = string
  default     = "su"
}

variable "bi_user_name" {
  description = "BI пользователь ClickHouse (например, bi_user), readonly доступ"
  type        = string
  default     = "bi_user"
}

variable "super_user_password" {
  description = "Пароль super_user (plain, только через env!)"
  type        = string
  sensitive   = true
}

variable "bi_user_password" {
  description = "Пароль bi_user (plain, только через env!)"
  type        = string
  sensitive   = true
}

variable "ch_version" {
  description = "ClickHouse server version"
  type        = string
  default     = "25.5.2-alpine"
}

variable "chk_version" {
  description = "ClickHouse keeper version"
  type        = string
  default     = "25.5.2-alpine"
}

variable "minio_version" {
  description = "MinIO version"
  type        = string
  default     = "RELEASE.2025-07-23T15-54-02Z"
}

variable "ch_uid" {
  description = "UID для clickhouse пользователя в контейнере"
  type        = string
  default     = "101"
}

variable "ch_gid" {
  description = "GID для clickhouse пользователя в контейнере"
  type        = string
  default     = "101"
}

# Переменные для управления портами
variable "use_standard_ports" {
  description = "Использовать стандартные порты для всех нод ClickHouse."
  type        = bool
  default     = true
}

variable "ch_http_port" {
  description = "Стандартный HTTP порт для ClickHouse."
  type        = number
  default     = 8123
}

variable "ch_tcp_port" {
  description = "Стандартный TCP порт для ClickHouse."
  type        = number
  default     = 9000
}

variable "ch_replication_port" {
  description = "Стандартный порт репликации для ClickHouse."
  type        = number
  default     = 9001
}

# MinIO and Backup variables
variable "minio_root_user" {
  description = "Пользователь для доступа к MinIO"
  type        = string
  sensitive   = true
}

variable "minio_root_password" {
  description = "Пароль для доступа к MinIO"
  type        = string
  sensitive   = true
}

variable "remote_ssh_user" {
  description = "Имя пользователя для SSH-доступа к удаленному хосту"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Путь к приватному SSH-ключу для доступа к удаленному хосту"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "local_minio_port" {
  description = "Порт для локального MinIO"
  type        = number
  default     = 9010
}

variable "remote_minio_port" {
  description = "Порт для удаленного MinIO (backup)"
  type        = number
  default     = 9000
}

variable "local_backup_minio_port" {
  description = "Порт для локального MinIO (backup)"
  type        = number
  default     = 9020
}

variable "storage_type" {
  description = "Тип основного хранилища для ClickHouse: 'local_ssd' или 's3_ssd'"
  type        = string
  default     = "local_ssd"
  validation {
    condition     = contains(["local_ssd", "s3_ssd", "local_storage"], var.storage_type)
    error_message = "Допустимые значения для storage_type: 'local_ssd', 's3_ssd' или 'local_storage'."
  }
}

variable "local_minio_path" {
  description = "Путь к данным для локального MinIO на внешнем SSD"
  type        = string
  default     = "/Users/principalwater/docker_volumes/minio/data"
}

variable "remote_minio_path" {
  description = "Путь к данным для удаленного MinIO на Raspberry Pi"
  type        = string
  default     = "/mnt/ssd/minio/data"
}

variable "local_backup_minio_path" {
  description = "Путь к данным для локального MinIO (backup)"
  type        = string
  default     = "../minio_backup/data"
}

variable "remote_host_name" {
  description = "Имя хоста для удаленного MinIO"
  type        = string
  default     = "water-rpi.local"
}

variable "bucket_backup" {
  description = "Имя бакета для бэкапов"
  type        = string
  default     = "clickhouse-backups"
}

variable "bucket_storage" {
  description = "Имя бакета для S3 хранилища"
  type        = string
  default     = "clickhouse-storage-bucket"
}

# --------------------------------------------------------------------------------------------------
# BI Infra Variables
# --------------------------------------------------------------------------------------------------

variable "deploy_superset" {
  description = "Развернуть Apache Superset."
  type        = bool
  default     = true
}

variable "deploy_metabase" {
  description = "Развернуть Metabase."
  type        = bool
  default     = true
}

variable "postgres_version" {
  description = "Версия Docker-образа Postgres для BI."
  type        = string
  default     = "16"
}

variable "metabase_version" {
  description = "Версия Docker-образа Metabase."
  type        = string
  default     = "v0.49.8"
}

variable "superset_version" {
  description = "Версия Docker-образа Superset."
  type        = string
  default     = "3.1.1"
}

variable "metabase_port" {
  description = "Порт для UI Metabase."
  type        = number
  default     = 3000
}

variable "superset_port" {
  description = "Порт для UI Superset."
  type        = number
  default     = 8088
}

variable "pg_password" {
  description = "Пароль для суперпользователя Postgres в BI-инфраструктуре."
  type        = string
  sensitive   = true
}

variable "sa_username" {
  description = "Имя главного администратора для Metabase и Superset."
  type        = string
  default     = "admin"
}

variable "sa_password" {
  description = "Пароль главного администратора для Metabase и Superset."
  type        = string
  sensitive   = true
}

variable "superset_secret_key" {
  description = "Секретный ключ для безопасности Superset."
  type        = string
  sensitive   = true
}

variable "postgres_restore_enabled" {
  description = "Включить восстановление/инициализацию Postgres."
  type        = bool
  default     = true
}

variable "metabase_pg_user" {
  description = "Имя пользователя Postgres для БД Metabase."
  type        = string
  default     = "metabase"
}

variable "superset_pg_user" {
  description = "Имя пользователя Postgres для БД Superset."
  type        = string
  default     = "superset"
}

variable "metabase_pg_db" {
  description = "Имя БД для Metabase."
  type        = string
  default     = "metabaseappdb"
}

variable "superset_pg_db" {
  description = "Имя БД для метаданных Superset."
  type        = string
  default     = "superset"
}

variable "metabase_site_name" {
  description = "Имя сайта Metabase."
  type        = string
  default     = "EnergyHub Metabase"
}

variable "bi_postgres_data_path" {
  description = "Путь к данным Postgres для BI-инструментов."
  type        = string
  default     = "../../volumes/postgres/data"
}

variable "metabase_local_users" {
  description = "Список локальных пользователей Metabase для создания через API. Оставьте пустым для использования sa_username и bi_user."
  type        = any
  default     = []
}

variable "superset_local_users" {
  description = "Список локальных пользователей Superset для создания через API. Оставьте пустым для использования sa_username и bi_user."
  type        = any
  default     = []
}

# --------------------------------------------------------------------------------------------------
# Kafka Variables
# --------------------------------------------------------------------------------------------------

variable "kafka_admin_user" {
  description = "Имя пользователя-администратора для Kafka."
  type        = string
  default     = "admin"
}

variable "kafka_admin_password" {
  description = "Пароль для пользователя-администратора Kafka."
  type        = string
  sensitive   = true
}

variable "kafka_ssl_keystore_password" {
  description = "Пароль для Keystore и Truststore Kafka."
  type        = string
  sensitive   = true
}

variable "kafka_version" {
  description = "Версия для Docker-образов Confluent Platform."
  type        = string
  default     = "7.2.15"
}

variable "topic_1min" {
  description = "Название топика для 1-минутных данных."
  type        = string
  default     = "energy_data_1min"
}

variable "topic_5min" {
  description = "Название топика для 5-минутных данных."
  type        = string
  default     = "energy_data_5min"
}

# --------------------------------------------------------------------------------------------------
# Monitoring Variables
# --------------------------------------------------------------------------------------------------

variable "portainer_version" {
  description = "Версия Portainer CE."
  type        = string
  default     = "latest"
}

variable "portainer_https_port" {
  description = "Порт для HTTPS-интерфейса Portainer."
  type        = number
  default     = 9443
}

variable "portainer_agent_port" {
  description = "Порт для Docker agent."
  type        = number
  default     = 10010
}

# --------------------------------------------------------------------------------------------------
# Airflow Variables
# --------------------------------------------------------------------------------------------------

variable "deploy_airflow" {
  description = "Развернуть Apache Airflow."
  type        = bool
  default     = false
}

variable "airflow_version" {
  description = "Версия Docker-образа Apache Airflow."
  type        = string
  default     = "2.8.1"
}



variable "redis_version" {
  description = "Версия Docker-образа Redis для Celery брокера."
  type        = string
  default     = "7.2-alpine"
}

variable "airflow_webserver_port" {
  description = "Порт для веб-интерфейса Airflow на хосте."
  type        = number
  default     = 8080
}

variable "airflow_flower_port" {
  description = "Порт для мониторинга Celery Flower на хосте."
  type        = number
  default     = 5555
}

variable "airflow_postgres_user" {
  description = "Имя пользователя PostgreSQL для Airflow."
  type        = string
  default     = "airflow"
}

variable "airflow_postgres_db" {
  description = "Имя базы данных PostgreSQL для Airflow."
  type        = string
  default     = "airflow"
}
variable "airflow_postgres_password" {
  description = "Пароль PostgreSQL для пользователя Airflow."
  type        = string
  sensitive   = true
}



variable "airflow_redis_data_path" {
  description = "Путь к директории с данными Redis для Airflow."
  type        = string
  default     = "../../volumes/airflow/redis"
}

variable "airflow_admin_user" {
  description = "Имя пользователя-администратора Airflow."
  type        = string
  default     = "admin"
}

variable "airflow_admin_password" {
  description = "Пароль пользователя-администратора Airflow."
  type        = string
  sensitive   = true
}

variable "airflow_fernet_key" {
  description = "Fernet ключ для шифрования в Airflow."
  type        = string
  sensitive   = true
}

variable "airflow_webserver_secret_key" {
  description = "Секретный ключ для веб-сервера Airflow."
  type        = string
  sensitive   = true
}

variable "airflow_dags_path" {
  description = "Путь к директории с DAG файлами Airflow."
  type        = string
  default     = "../../volumes/airflow/dags"
}

variable "airflow_logs_path" {
  description = "Путь к директории с логами Airflow."
  type        = string
  default     = "../../volumes/airflow/logs"
}

variable "airflow_plugins_path" {
  description = "Путь к директории с плагинами Airflow."
  type        = string
  default     = "../../volumes/airflow/plugins"
}

variable "airflow_config_path" {
  description = "Путь к директории с конфигурацией Airflow."
  type        = string
  default     = "../../volumes/airflow/config"
}

# --- DBT Variables ---

variable "deploy_dbt" {
  description = "Включить развертывание dbt модуля"
  type        = bool
  default     = true
}

variable "dbt_version" {
  description = "Версия dbt для ClickHouse"
  type        = string
  default     = "1.7.3"
}

variable "dbt_port" {
  description = "Порт для dbt сервиса"
  type        = number
  default     = 8080
}

variable "dbt_base_path" {
  description = "Базовый путь для dbt проекта"
  type        = string
  default     = "../../dbt"
}
