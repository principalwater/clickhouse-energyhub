# --------------------------------------------------------------------------------------------------
# OUTPUTS для модуля Kafka
# --------------------------------------------------------------------------------------------------

output "kafka_bootstrap_servers_plaintext" {
  description = "Bootstrap серверы Kafka для PLAINTEXT подключений."
  value       = "localhost:9092"
}

output "kafka_bootstrap_servers_sasl_ssl" {
  description = "Bootstrap серверы Kafka для SASL_SSL подключений."
  value       = "localhost:9093"
}

output "kafka_container_name" {
  description = "Имя контейнера Kafka."
  value       = docker_container.kafka.name
}

output "zookeeper_container_name" {
  description = "Имя контейнера Zookeeper."
  value       = docker_container.zookeeper.name
}

output "kafka_admin_user" {
  description = "Имя пользователя-администратора Kafka."
  value       = var.kafka_admin_user
}

output "kafka_topics" {
  description = "Список созданных топиков Kafka."
  value = [
    var.topic_1min,
    var.topic_5min
  ]
}

output "secrets_path" {
  description = "Путь к директории с секретами Kafka."
  value       = var.secrets_path
}

output "network_name" {
  description = "Имя Docker-сети Kafka."
  value       = docker_network.kafka_network.name
}
