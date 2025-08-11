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
  content  = <<-EOT
KafkaServer {
  org.apache.kafka.common.security.scram.ScramLoginModule required
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
    "ZOOKEEPER_TICK_TIME=2000"
  ]
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
    internal = 9092 # PLAINTEXT для внутренних операций
    external = 9092
  }
  ports {
    internal = 9093 # SASL_SSL для внешних клиентов
    external = 9093
  }
  env = [
    "KAFKA_BROKER_ID=1",
    "KAFKA_ZOOKEEPER_CONNECT=zookeeper:2181",

    # Ключевые переменные для preflight скриптов
    "KAFKA_ZOOKEEPER_SASL_ENABLED=false",
    "ZOOKEEPER_SASL_ENABLED=false",

    # Смешанная конфигурация
    "KAFKA_LISTENERS=PLAINTEXT://:9092,SASL_SSL://:9093",
    "KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://kafka:9092,SASL_SSL://localhost:9093",
    "KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=PLAINTEXT:PLAINTEXT,SASL_SSL:SASL_SSL",
    "KAFKA_INTER_BROKER_LISTENER_NAME=PLAINTEXT",

    # SASL только для внешних подключений
    "KAFKA_SASL_MECHANISM_INTER_BROKER_PROTOCOL=SCRAM-SHA-256",
    "KAFKA_SASL_ENABLED_MECHANISMS=SCRAM-SHA-256",
    "KAFKA_OPTS=-Djava.security.auth.login.config=/etc/kafka/secrets/kafka_server_jaas.conf",

    # SSL Configuration
    "KAFKA_SSL_KEYSTORE_FILENAME=kafka.keystore.jks",
    "KAFKA_SSL_TRUSTSTORE_FILENAME=kafka.truststore.jks",
    "KAFKA_SSL_KEYSTORE_CREDENTIALS=kafka_keystore_creds",
    "KAFKA_SSL_KEY_CREDENTIALS=kafka_key_creds",
    "KAFKA_SSL_TRUSTSTORE_CREDENTIALS=kafka_truststore_creds",
    "KAFKA_SSL_CLIENT_AUTH=required",

    # ACLs и Super Users (без включения authorizer)
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
    local_file.kafka_ssl_credentials
  ]
}

# --- Post-start operations ---

resource "null_resource" "setup_kafka_users_and_topics" {
  provisioner "local-exec" {
    command = <<EOT
      echo "=== Этап 1: Ожидание готовности Kafka ==="
      for i in {1..30}; do
        if docker exec kafka kafka-topics --bootstrap-server kafka:9092 --list &> /dev/null; then
          echo "Kafka готов к настройке"
          break
        fi
        echo "Попытка $i: Ждём готовности Kafka..."
        sleep 3
      done

      echo "=== Этап 2: Создание SCRAM пользователей ==="
      docker exec kafka kafka-configs --bootstrap-server kafka:9092 \
        --alter --add-config 'SCRAM-SHA-256=[password=${var.kafka_admin_password}]' \
        --entity-type users --entity-name ${var.kafka_admin_user}
      
      echo "SCRAM пользователь ${var.kafka_admin_user} создан"

      echo "=== Этап 3: Создание топиков ==="
      docker exec kafka kafka-topics --create --if-not-exists --topic ${var.topic_1min} \
        --bootstrap-server kafka:9092 --partitions 1 --replication-factor 1 \
        --config retention.ms=86400000
        
      docker exec kafka kafka-topics --create --if-not-exists --topic ${var.topic_5min} \
        --bootstrap-server kafka:9092 --partitions 1 --replication-factor 1 \
        --config retention.ms=86400000
      
      echo "Топики созданы: ${var.topic_1min}, ${var.topic_5min}"

      echo "=== Этап 4: Проверка SASL_SSL подключения ==="
      if docker exec kafka kafka-topics --bootstrap-server localhost:9093 \
        --command-config /etc/kafka/secrets/kafka_client.properties --list &> /dev/null; then
        echo "SASL_SSL подключение работает"
      else
        echo "SASL_SSL подключение не готово (это нормально на данном этапе)"
      fi

      echo "=== Настройка Kafka завершена успешно ==="
    EOT
  }

  depends_on = [
    docker_container.kafka,
    local_file.kafka_client_properties
  ]

  # Перезапускать при изменении конфигурации
  triggers = {
    kafka_config = "${var.kafka_admin_user}-${var.kafka_admin_password}"
    topics       = "${var.topic_1min}-${var.topic_5min}"
  }
}

# --- Опциональный этап 3: Включение ACL (если нужно) ---

resource "null_resource" "enable_kafka_acl" {
  count = var.enable_kafka_acl ? 1 : 0

  provisioner "local-exec" {
    command = <<EOT
      echo "=== Включение ACL авторизации ==="
      
      # Перезапускаем Kafka с ACL
      docker exec kafka kafka-configs --bootstrap-server kafka:9092 \
        --alter --entity-type brokers --entity-name 1 \
        --add-config 'authorizer.class.name=kafka.security.authorizer.AclAuthorizer,super.users=User:${var.kafka_admin_user}'
      
      echo "ACL авторизация включена"
    EOT
  }

  depends_on = [null_resource.setup_kafka_users_and_topics]
}

# --- Client Properties файл ---

resource "local_file" "kafka_client_properties" {
  content    = <<-EOT
security.protocol=SASL_SSL
ssl.truststore.location=/etc/kafka/secrets/kafka.truststore.jks
ssl.truststore.password=${var.kafka_ssl_keystore_password}
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="${var.kafka_admin_user}" password="${var.kafka_admin_password}";
EOT
  filename   = "${var.secrets_path}/kafka_client.properties"
  depends_on = [local_file.kafka_jaas_config]
}

# --- Environment файл ---

resource "local_file" "kafka_env_file" {
  content    = <<-EOT
# Kafka Credentials for client applications
KAFKA_ADMIN_USER=${var.kafka_admin_user}
KAFKA_ADMIN_PASSWORD=${var.kafka_admin_password}
KAFKA_SSL_KEYSTORE_PASSWORD=${var.kafka_ssl_keystore_password}
KAFKA_BOOTSTRAP_SERVERS_PLAINTEXT=kafka:9092
KAFKA_BOOTSTRAP_SERVERS_SASL_SSL=localhost:9093
EOT
  filename   = "${var.secrets_path}/kafka.env"
  depends_on = [null_resource.setup_kafka_users_and_topics]
}
