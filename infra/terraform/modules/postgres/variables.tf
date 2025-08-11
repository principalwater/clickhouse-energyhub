# --------------------------------------------------------------------------------------------------
# INPUT VARIABLES для модуля PostgreSQL
# --------------------------------------------------------------------------------------------------

# ---- Section: Основные настройки ----
variable "enable_postgres" {
  description = "Включить PostgreSQL."
  type        = bool
  default     = true
}

variable "postgres_version" {
  description = "Версия Docker-образа PostgreSQL."
  type        = string
  default     = "16"
}

variable "postgres_data_path" {
  description = "Путь к директории с данными PostgreSQL."
  type        = string
  default     = "../../volumes/postgres/data"
}

variable "postgres_superuser_password" {
  description = "Пароль суперпользователя PostgreSQL."
  type        = string
  sensitive   = true
}

variable "pg_password" {
  description = "Общий пароль PostgreSQL, используемый как fallback для всех пользователей."
  type        = string
  sensitive   = true
}

variable "postgres_restore_enabled" {
  description = "Включить восстановление/инициализацию PostgreSQL."
  type        = bool
  default     = true
}

# ---- Section: Флаги включения сервисов ----
variable "enable_metabase" {
  description = "Включить поддержку Metabase в PostgreSQL."
  type        = bool
  default     = false
}

variable "enable_superset" {
  description = "Включить поддержку Superset в PostgreSQL."
  type        = bool
  default     = false
}

variable "enable_airflow" {
  description = "Включить поддержку Airflow в PostgreSQL."
  type        = bool
  default     = false
}

# ---- Section: Metabase настройки ----
variable "metabase_pg_user" {
  description = "Имя пользователя PostgreSQL для Metabase."
  type        = string
  default     = "metabase"
}

variable "metabase_pg_password" {
  description = "Пароль PostgreSQL для пользователя Metabase."
  type        = string
  sensitive   = true
}

variable "metabase_pg_db" {
  description = "Имя базы данных PostgreSQL для Metabase."
  type        = string
  default     = "metabaseappdb"
}

# ---- Section: Superset настройки ----
variable "superset_pg_user" {
  description = "Имя пользователя PostgreSQL для Superset."
  type        = string
  default     = "superset"
}

variable "superset_pg_password" {
  description = "Пароль PostgreSQL для пользователя Superset."
  type        = string
  sensitive   = true
}

variable "superset_pg_db" {
  description = "Имя базы данных PostgreSQL для Superset."
  type        = string
  default     = "superset"
}

# ---- Section: Airflow настройки ----
variable "airflow_pg_user" {
  description = "Имя пользователя PostgreSQL для Airflow."
  type        = string
  default     = "airflow"
}

variable "airflow_pg_password" {
  description = "Пароль PostgreSQL для пользователя Airflow."
  type        = string
  sensitive   = true
}

variable "airflow_pg_db" {
  description = "Имя базы данных PostgreSQL для Airflow."
  type        = string
  default     = "airflow"
}
