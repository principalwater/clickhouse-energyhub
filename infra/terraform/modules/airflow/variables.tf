# --------------------------------------------------------------------------------------------------
# INPUT VARIABLES для модуля Airflow
# --------------------------------------------------------------------------------------------------

# ---- Section: Основные флаги развертывания ----
variable "deploy_airflow" {
  description = "Развернуть Apache Airflow."
  type        = bool
  default     = false
}

# ---- Section: Версии Docker-образов ----
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

# ---- Section: Порты сервисов ----
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

# ---- Section: PostgreSQL настройки ----
variable "airflow_postgres_connection_string" {
  description = "Строка подключения к PostgreSQL для Airflow."
  type        = string
  sensitive   = true
}

# ---- Section: Redis настройки ----
variable "airflow_redis_data_path" {
  description = "Путь к директории с данными Redis для Airflow."
  type        = string
  default     = "../../volumes/airflow/redis"
}

# ---- Section: Airflow настройки ----
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

# ---- Section: Пути к директориям Airflow ----
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

# ---- Section: Интеграция с ClickHouse ----
variable "clickhouse_network_name" {
  description = "Имя Docker-сети ClickHouse для интеграции."
  type        = string
}

variable "clickhouse_bi_user" {
  description = "Имя BI пользователя ClickHouse для подключения Airflow."
  type        = string
}

variable "clickhouse_bi_password" {
  description = "Пароль BI пользователя ClickHouse для подключения Airflow."
  type        = string
  sensitive   = true
}

# ---- Section: Интеграция с Kafka ----
variable "kafka_network_name" {
  description = "Имя Docker-сети Kafka для интеграции."
  type        = string
}

variable "kafka_topic_1min" {
  description = "Название топика Kafka для 1-минутных данных."
  type        = string
}

variable "kafka_topic_5min" {
  description = "Название топика Kafka для 5-минутных данных."
  type        = string
}
