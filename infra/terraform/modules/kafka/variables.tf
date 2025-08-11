variable "kafka_version" {
  description = "Версия для Docker-образов Confluent Platform (Kafka, Zookeeper)."
  type        = string
}

variable "docker_network_name" {
  description = "Имя Docker-сети, к которой будут подключены контейнеры."
  type        = string
}

variable "topic_1min" {
  description = "Название топика для 1-минутных данных."
  type        = string
}

variable "topic_5min" {
  description = "Название топика для 5-минутных данных."
  type        = string
}

variable "kafka_admin_user" {
  description = "Имя пользователя-администратора для Kafka."
  type        = string
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

variable "secrets_path" {
  description = "Абсолютный путь к директории с секретами для Kafka."
  type        = string
}
