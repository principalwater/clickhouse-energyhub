# --------------------------------------------------------------------------------------------------
# INPUT VARIABLES
# --------------------------------------------------------------------------------------------------
# Эти переменные определяют интерфейс модуля.
# Значения по умолчанию для них задаются в корневом файле variables.tf.
# --------------------------------------------------------------------------------------------------

variable "clickhouse_base_path" {
  description = "Базовый путь для данных и конфигураций ClickHouse."
  type        = string
}

variable "memory_limit" {
  description = "Ограничение по памяти для контейнеров ClickHouse."
  type        = number
}

variable "super_user_name" {
  description = "Имя основного пользователя ClickHouse."
  type        = string
}

variable "bi_user_name" {
  description = "Имя BI-пользователя ClickHouse (readonly)."
  type        = string
}

variable "super_user_password" {
  description = "Пароль для super_user."
  type        = string
  sensitive   = true
}

variable "bi_user_password" {
  description = "Пароль для bi_user."
  type        = string
  sensitive   = true
}

variable "ch_version" {
  description = "Версия ClickHouse server."
  type        = string
}

variable "chk_version" {
  description = "Версия ClickHouse keeper."
  type        = string
}

variable "minio_version" {
  description = "Версия MinIO."
  type        = string
}

variable "ch_uid" {
  description = "UID для пользователя clickhouse в контейнере."
  type        = string
}

variable "ch_gid" {
  description = "GID для пользователя clickhouse в контейнере."
  type        = string
}

variable "use_standard_ports" {
  description = "Использовать стандартные порты для всех нод ClickHouse."
  type        = bool
}

variable "ch_http_port" {
  description = "Стандартный HTTP порт для ClickHouse."
  type        = number
}

variable "ch_tcp_port" {
  description = "Стандартный TCP порт для ClickHouse."
  type        = number
}

variable "ch_replication_port" {
  description = "Стандартный порт репликации для ClickHouse."
  type        = number
}

variable "minio_root_user" {
  description = "Пользователь для доступа к MinIO."
  type        = string
  sensitive   = true
}

variable "minio_root_password" {
  description = "Пароль для доступа к MinIO."
  type        = string
  sensitive   = true
}

variable "remote_ssh_user" {
  description = "Имя пользователя для SSH-доступа к удаленному хосту."
  type        = string
}

variable "ssh_private_key_path" {
  description = "Путь к приватному SSH-ключу для доступа к удаленному хосту."
  type        = string
}

variable "local_minio_port" {
  description = "Порт для локального MinIO (для s3_ssd)."
  type        = number
}

variable "remote_minio_port" {
  description = "Порт для удаленного MinIO (для бэкапов)."
  type        = number
}

variable "local_backup_minio_port" {
  description = "Порт для локального MinIO (для бэкапов в режиме local_storage)."
  type        = number
}

variable "storage_type" {
  description = "Тип хранилища: 'local_ssd', 's3_ssd' или 'local_storage'."
  type        = string
}

variable "local_minio_path" {
  description = "Путь к данным для локального MinIO (s3_ssd)."
  type        = string
}

variable "remote_minio_path" {
  description = "Путь к данным для удаленного MinIO."
  type        = string
}

variable "local_backup_minio_path" {
  description = "Путь к данным для локального MinIO (бэкап)."
  type        = string
}

variable "remote_host_name" {
  description = "Имя хоста для удаленного MinIO."
  type        = string
}

variable "bucket_backup" {
  description = "Имя бакета для бэкапов."
  type        = string
}

variable "bucket_storage" {
  description = "Имя бакета для S3 хранилища."
  type        = string
}
