locals {
  # JAAS config for external clients connecting to Kafka (using SCRAM)
  kafka_client_scram_config = "org.apache.kafka.common.security.scram.ScramLoginModule required username=\"${var.kafka_admin_user}\" password=\"${var.kafka_admin_password}\";"
}
