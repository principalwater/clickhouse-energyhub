variable "clickhouse_base_path" {
  type    = string
  default = "../clickhouse/volumes"
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

variable "storage_type" {
  description = "Тип основного хранилища для ClickHouse: 'local_ssd' или 's3_ssd'"
  type        = string
  default     = "local_ssd"
  validation {
    condition     = contains(["local_ssd", "s3_ssd"], var.storage_type)
    error_message = "Допустимые значения для storage_type: 'local_ssd' или 's3_ssd'."
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
