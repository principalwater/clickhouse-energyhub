terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.6.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.3"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
    }
  }
}

# --- Certificate and Config Generation ---

resource "null_resource" "generate_kafka_certs" {
  provisioner "local-exec" {
    command = "bash ${path.root}/../../scripts/generate_certs.sh '${var.kafka_ssl_keystore_password}' '${var.kafka_version}'"
  }
  triggers = {
    script_hash = filemd5("${path.root}/../../scripts/generate_certs.sh")
  }
}

resource "local_file" "kafka_jaas_config" {
  content = <<-EOT
KafkaServer {
  org.apache.kafka.common.security.scram.ScramLoginModule required
  username="${var.kafka_admin_user}"
  password="${var.kafka_admin_password}";
};

Client {
  org.apache.kafka.common.security.plain.PlainLoginModule required
  username="${var.kafka_admin_user}"
  password="${var.kafka_admin_password}";
};
EOT
  filename = "${var.secrets_path}/kafka_server_jaas.conf"

  depends_on = [null_resource.generate_kafka_certs]
}

# Создание файлов с паролями для SSL
resource "local_file" "kafka_ssl_credentials" {
  for_each = {
    "kafka_keystore_creds"   = var.kafka_ssl_keystore_password
    "kafka_key_creds"        = var.kafka_ssl_keystore_password  
    "kafka_truststore_creds" = var.kafka_ssl_keystore_password
  }
  
  content  = each.value
  filename = "${var.secrets_path}/${each.key}"
  
  depends_on = [null_resource.generate_kafka_certs]
}

# --- Zookeeper Setup ---

resource "docker_image" "zookeeper" {
  name = "confluentinc/cp-zookeeper:${var.kafka_version}"
}

resource "local_file" "zookeeper_jaas_config" {
  content = <<-EOT
Server {
  org.apache.kafka.common.security.plain.PlainLoginModule required
  username="${var.kafka_admin_user}"
  password="${var.kafka_admin_password}"
  user_${var.kafka_admin_user}="${var.kafka_admin_password}";
};
EOT
  filename = "${var.secrets_path}/zookeeper_server_jaas.conf"
  
  depends_on = [null_resource.generate_kafka_certs]
}

resource "docker_container" "zookeeper" {
  name     = "zookeeper"
  image    = docker_image.zookeeper.name
  hostname = "zookeeper"
  networks_advanced {
    name    = var.docker_network_name
    aliases = ["zookeeper"]
  }
  ports {
    internal = 2181
    external = 2181
  }
  env = [
    "ZOOKEEPER_CLIENT_PORT=2181",
    "ZOOKEEPER_TICK_TIME=2000",
    
    # Включить SASL в Zookeeper
    "ZOOKEEPER_AUTH_PROVIDER_1=org.apache.zookeeper.server.auth.SASLAuthenticationProvider",
    "ZOOKEEPER_REQUIRE_CLIENT_AUTH_SCHEME=sasl",
    
    # Указать путь к JAAS файлу
    "KAFKA_OPTS=-Djava.security.auth.login.config=/etc/zookeeper/secrets/zookeeper_server_jaas.conf"
  ]
  volumes {
    host_path      = var.secrets_path
    container_path = "/etc/zookeeper/secrets"
    read_only      = true
  }
  depends_on = [local_file.zookeeper_jaas_config]
}

# --- Kafka Setup ---

resource "docker_image" "kafka" {
  name = "confluentinc/cp-kafka:${var.kafka_version}"
}

resource "docker_container" "kafka" {
  name     = "kafka"
  image    = docker_image.kafka.name
  hostname = "kafka"
  networks_advanced {
    name    = var.docker_network_name
    aliases = ["kafka"]
  }
  ports {
    internal = 9093
    external = 9093
  }
  env = [
    "KAFKA_BROKER_ID=1",
    "KAFKA_ZOOKEEPER_CONNECT=zookeeper:2181",
    "KAFKA_LISTENERS=SASL_SSL://:9093",
    "KAFKA_ADVERTISED_LISTENERS=SASL_SSL://localhost:9093",
    "KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=SASL_SSL:SASL_SSL",
    "KAFKA_INTER_BROKER_LISTENER_NAME=SASL_SSL",

    # SASL/SCRAM Configuration
    "KAFKA_SASL_MECHANISM_INTER_BROKER_PROTOCOL=SCRAM-SHA-256",
    "KAFKA_SASL_ENABLED_MECHANISMS=SCRAM-SHA-256",
    "KAFKA_OPTS=-Djava.security.auth.login.config=/etc/kafka/secrets/kafka_server_jaas.conf",

    # SSL Configuration с CREDENTIALS файлами
    "KAFKA_SSL_KEYSTORE_FILENAME=kafka.keystore.jks",
    "KAFKA_SSL_TRUSTSTORE_FILENAME=kafka.truststore.jks",
    "KAFKA_SSL_KEYSTORE_CREDENTIALS=kafka_keystore_creds",
    "KAFKA_SSL_KEY_CREDENTIALS=kafka_key_creds", 
    "KAFKA_SSL_TRUSTSTORE_CREDENTIALS=kafka_truststore_creds",
    "KAFKA_SSL_CLIENT_AUTH=required",

    # ACLs and Super Users
    "KAFKA_AUTHORIZER_CLASS_NAME=kafka.security.authorizer.AclAuthorizer",
    "KAFKA_SUPER_USERS=User:${var.kafka_admin_user}",
    "KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1"
  ]
  volumes {
    host_path      = var.secrets_path
    container_path = "/etc/kafka/secrets"
    read_only      = true
  }
  depends_on = [
    docker_container.zookeeper,
    null_resource.generate_kafka_certs,
    local_file.kafka_jaas_config,
    local_file.kafka_ssl_credentials,
    local_file.zookeeper_jaas_config
  ]
}

# --- Post-start operations ---

resource "local_file" "kafka_client_properties" {
  content = <<-EOT
    security.protocol=SASL_SSL
    ssl.truststore.location=/tmp/secrets/kafka.truststore.jks
    ssl.truststore.password=${var.kafka_ssl_keystore_password}
    sasl.mechanism=SCRAM-SHA-256
    sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="${var.kafka_admin_user}" password="${var.kafka_admin_password}";
  EOT
  filename = "${var.secrets_path}/kafka_client.properties"

  depends_on = [local_file.kafka_jaas_config]
}

resource "null_resource" "create_kafka_topics" {
  provisioner "local-exec" {
    command = <<EOT
      # Wait for Kafka to be ready
      echo "Waiting for Kafka to be ready..."
      for i in {1..30}; do
          # We need to mount the secrets directory to the temp container to run kafka-topics
          # Note: We connect to localhost:9093 because this is the external listener
          if docker run --rm -v ${var.secrets_path}:/tmp/secrets confluentinc/cp-kafka:${var.kafka_version} kafka-topics --bootstrap-server host.docker.internal:9093 --list --command-config /tmp/secrets/kafka_client.properties &> /dev/null; then
            echo "Kafka is ready."
            break
          fi
        echo "Attempt $i: Kafka not ready yet, sleeping 2s..."
        sleep 2
      done

          # Create topics with retention policy
          docker run --rm -v ${var.secrets_path}:/tmp/secrets confluentinc/cp-kafka:${var.kafka_version} kafka-topics --create --if-not-exists --topic ${var.topic_1min} --bootstrap-server host.docker.internal:9093 --partitions 1 --replication-factor 1 --command-config /tmp/secrets/kafka_client.properties --config retention.ms=86400000
          docker run --rm -v ${var.secrets_path}:/tmp/secrets confluentinc/cp-kafka:${var.kafka_version} kafka-topics --create --if-not-exists --topic ${var.topic_5min} --bootstrap-server host.docker.internal:9093 --partitions 1 --replication-factor 1 --command-config /tmp/secrets/kafka_client.properties --config retention.ms=86400000
      
      echo "Topics created and configured."
    EOT
  }
  depends_on = [
    docker_container.kafka,
    local_file.kafka_client_properties
  ]
}

resource "local_file" "kafka_env_file" {
  content  = <<-EOT
# Kafka Credentials for client applications
KAFKA_ADMIN_USER=${var.kafka_admin_user}
KAFKA_ADMIN_PASSWORD=${var.kafka_admin_password}
KAFKA_SSL_KEYSTORE_PASSWORD=${var.kafka_ssl_keystore_password}
EOT
  filename = "${var.secrets_path}/../env/kafka.env"
}
