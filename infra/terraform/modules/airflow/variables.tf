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

variable "airflow_postgres_password" {
  description = "Пароль пользователя PostgreSQL для Airflow."
  type        = string
  sensitive   = true
}

variable "postgres_network_name" {
  description = "Имя Docker-сети PostgreSQL для подключения к базе данных."
  type        = string
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
  default     = "../../airflow/dags"
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

variable "scripts_path" {
  description = "Путь к директории со скриптами для Airflow."
  type        = string
  default     = "../../scripts"
}

# ---- Section: ClickHouse интеграция ----
variable "clickhouse_network_name" {
  description = "Имя Docker-сети ClickHouse для подключения."
  type        = string
}

variable "clickhouse_bi_user" {
  description = "Имя пользователя ClickHouse для BI операций."
  type        = string
}

variable "clickhouse_bi_password" {
  description = "Пароль пользователя ClickHouse для BI операций."
  type        = string
  sensitive   = true
}

variable "clickhouse_super_user" {
  description = "Имя суперпользователя ClickHouse."
  type        = string
}

variable "clickhouse_super_password" {
  description = "Пароль суперпользователя ClickHouse."
  type        = string
  sensitive   = true
}

# ---- Section: Kafka интеграция ----
variable "kafka_network_name" {
  description = "Имя Docker-сети Kafka для подключения."
  type        = string
}

variable "kafka_topic_1min" {
  description = "Название топика Kafka для данных с интервалом 1 минута."
  type        = string
}

variable "kafka_topic_5min" {
  description = "Название топика Kafka для данных с интервалом 5 минут."
  type        = string
}

# ---- Section: Telegram интеграция ----
variable "telegram_bot_token" {
  description = "Токен Telegram бота для отправки уведомлений."
  type        = string
  sensitive   = true
  default     = ""
}

variable "telegram_chat_id" {
  description = "ID чата/канала Telegram для отправки уведомлений."
  type        = string
  default     = ""
}

variable "enable_flower" {
  description = "Включить Flower для мониторинга Celery"
  type        = bool
  default     = false
}

variable "disable_healthchecks" {
  description = "Отключить Docker healthcheck'и для проблемных контейнеров (worker, triggerer)"
  type        = bool
  default     = false
}
