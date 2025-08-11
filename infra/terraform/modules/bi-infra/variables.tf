# --------------------------------------------------------------------------------------------------
# INPUT VARIABLES
# --------------------------------------------------------------------------------------------------
# Эти переменные определяют интерфейс модуля bi-infra.
# Значения по умолчанию для них задаются в корневом файле variables.tf.
# --------------------------------------------------------------------------------------------------


# ---- Section: Versions and general parameters ----
variable "postgres_version" {
  description = "Версия Docker-образа Postgres."
  type        = string
}

variable "metabase_version" {
  description = "Версия Docker-образа Metabase."
  type        = string
}

variable "metabase_port" {
  description = "Порт для UI Metabase на хосте."
  type        = number
}

variable "superset_version" {
  description = "Версия Docker-образа Superset."
  type        = string
}

variable "superset_port" {
  description = "Порт для UI Superset на хосте."
  type        = number
}

# ---- Section: Postgres database variables ----
variable "metabase_pg_user" {
  description = "Имя пользователя Postgres для БД Metabase."
  type        = string
}

variable "metabase_pg_password" {
  description = "Пароль Postgres для пользователя Metabase."
  type        = string
  sensitive   = true
}

variable "superset_pg_user" {
  description = "Имя пользователя Postgres для БД Superset."
  type        = string
}

variable "superset_pg_password" {
  description = "Пароль Postgres для пользователя Superset."
  type        = string
  sensitive   = true
}

variable "pg_password" {
  description = "Общий пароль Postgres, используемый для Metabase и Superset."
  type        = string
  sensitive   = true
}

variable "metabase_pg_db" {
  description = "Имя БД для Metabase."
  type        = string
}

variable "superset_pg_db" {
  description = "Имя БД для метаданных Superset."
  type        = string
}

# ---- Section: Global BI and SA user accounts ----
variable "sa_username" {
  description = "Основное имя администратора для Metabase и Superset."
  type        = string
}

variable "sa_password" {
  description = "Основной пароль администратора для Metabase и Superset."
  type        = string
  sensitive   = true
}

variable "bi_user" {
  description = "Основной логин BI-пользователя для Metabase и Superset."
  type        = string
}

variable "bi_password" {
  description = "Основной пароль BI-пользователя для Metabase и Superset."
  type        = string
  sensitive   = true
}

# ---- Section: Metabase settings ----
variable "metabase_site_name" {
  description = "Имя сайта Metabase для мастера установки."
  type        = string
}

variable "metabase_sa_username" {
  description = "Имя администратора Metabase (fallback: sa_username)."
  type        = string
}

variable "metabase_sa_password" {
  description = "Пароль администратора Metabase (fallback: sa_password)."
  type        = string
  sensitive   = true
}

variable "metabase_bi_username" {
  description = "Имя BI-пользователя Metabase (fallback: bi_user)."
  type        = string
}

variable "metabase_bi_password" {
  description = "Пароль BI-пользователя Metabase (fallback: bi_password)."
  type        = string
  sensitive   = true
}

# ---- Section: Superset settings ----
variable "superset_sa_username" {
  description = "Имя администратора Superset (fallback: sa_username)."
  type        = string
}

variable "superset_sa_password" {
  description = "Пароль администратора Superset (fallback: sa_password)."
  type        = string
  sensitive   = true
}

variable "superset_secret_key" {
  description = "Секретный ключ для безопасности Superset."
  type        = string
  sensitive   = true
}

variable "superset_bi_username" {
  description = "Имя BI-пользователя Superset (fallback: bi_user)."
  type        = string
}

variable "superset_bi_password" {
  description = "Пароль BI-пользователя Superset (fallback: bi_password)."
  type        = string
  sensitive   = true
}

# ---- Section: User lists for API creation ----
variable "metabase_local_users" {
  description = "Список локальных пользователей Metabase для создания через API."
  type        = any
}

variable "superset_local_users" {
  description = "Список локальных пользователей Superset для создания через API."
  type        = any
}

variable "deploy_metabase" {
  description = "Флаг для включения Metabase."
  type        = bool
}

variable "deploy_superset" {
  description = "Флаг для включения Superset."
  type        = bool
}

# ---- Section: Postgres superuser password ----
variable "postgres_superuser_password" {
  description = "Пароль суперпользователя Postgres."
  type        = string
  sensitive   = true
}

variable "postgres_restore_enabled" {
  description = "Включить восстановление/инициализацию данных Postgres, если директория pgdata пуста."
  type        = bool
  default     = true
}

# ---- Section: PostgreSQL connection from external module ----
variable "postgres_container_name" {
  description = "Имя контейнера PostgreSQL из внешнего модуля."
  type        = string
}

variable "postgres_network_name" {
  description = "Имя Docker-сети PostgreSQL из внешнего модуля."
  type        = string
}

# ---- Section: Airflow settings ----
variable "airflow_enabled" {
  description = "Флаг для включения поддержки Airflow в PostgreSQL."
  type        = bool
  default     = false
}

variable "airflow_pg_user" {
  description = "Имя пользователя PostgreSQL для Airflow."
  type        = string
  default     = "airflow"
}

variable "airflow_pg_password" {
  description = "Пароль пользователя PostgreSQL для Airflow."
  type        = string
  sensitive   = true
}

variable "airflow_pg_db" {
  description = "Имя базы данных PostgreSQL для Airflow."
  type        = string
  default     = "airflow"
}
