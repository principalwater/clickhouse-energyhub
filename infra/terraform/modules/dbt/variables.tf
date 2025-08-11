variable "dbt_project_name" {
  description = "Название dbt проекта"
  type        = string
  default     = "clickhouse_energyhub"
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

variable "dbt_host" {
  description = "Хост для dbt сервиса"
  type        = string
  default     = "localhost"
}

variable "dbt_base_path" {
  description = "Базовый путь для dbt проекта"
  type        = string
  default     = "../../dbt"
}

variable "clickhouse_host" {
  description = "Хост ClickHouse для подключения dbt"
  type        = string
  default     = "clickhouse-01"
}

variable "clickhouse_port" {
  description = "Порт ClickHouse для подключения dbt"
  type        = number
  default     = 9000
}

variable "clickhouse_database" {
  description = "База данных ClickHouse для dbt"
  type        = string
  default     = "default"
}

variable "clickhouse_user" {
  description = "Пользователь ClickHouse для dbt"
  type        = string
  default     = "bi_user"
}

variable "clickhouse_password" {
  description = "Пароль пользователя ClickHouse для dbt"
  type        = string
  sensitive   = true
}

variable "clickhouse_network_name" {
  description = "Название Docker сети для подключения к ClickHouse"
  type        = string
  default     = "clickhouse-net"
}
