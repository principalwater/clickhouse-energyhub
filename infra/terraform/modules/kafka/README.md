# Terraform Module: Apache Kafka

Этот модуль Terraform разворачивает готовый к использованию брокер Apache Kafka с Zookeeper и продвинутыми настройками безопасности, включая SSL/TLS шифрование и SASL/SCRAM аутентификацию.

## Архитектура

Модуль создает следующие компоненты:
- **Zookeeper:** Один контейнер `confluentinc/cp-zookeeper`, необходимый для координации Kafka.
- **Kafka Broker:** Один контейнер `confluentinc/cp-kafka` с поддержкой смешанной конфигурации протоколов.
- **SSL/TLS сертификаты:** Автоматическая генерация keystore и truststore с поддержкой множественных хостов.
- **Безопасность:** Настроена SASL/SCRAM аутентификация для внешних подключений и PLAINTEXT для внутренних операций.
- **Автоматическая настройка:** Создание пользователей, топиков и конфигурационных файлов.

Все компоненты запускаются в единой Docker-сети, имя которой передается в качестве переменной, что обеспечивает легкую интеграцию с другими сервисами.

## Особенности

- **Смешанная конфигурация протоколов:**
  - `PLAINTEXT://kafka:9092` - для внутренних операций между брокерами
  - `SASL_SSL://localhost:9093` - для внешних клиентских подключений
- **Автоматическая генерация SSL-сертификатов:** Использует внешний скрипт `generate_certs.sh` для создания keystore и truststore
- **SASL/SCRAM аутентификация:** Автоматическое создание администратора с настройкой SCRAM-SHA-256
- **Автоматическое создание топиков:** Создание топиков с настраиваемыми именами и политикой хранения (TTL = 1 день)
- **Готовые конфигурационные файлы:** 
  - `kafka_client.properties` - для подключения внешних клиентов
  - `kafka.env` - переменные окружения для приложений
  - `kafka_server_jaas.conf` - JAAS конфигурация сервера
- **Опциональные ACL:** Возможность включения авторизации на основе ACL

---

## Входные переменные (Input Variables)

| Имя | Описание | Тип | Обязательная |
| --- | --- | --- | --- |
| `kafka_version` | Версия для Docker-образов Confluent Platform | string | Да |
| `docker_network_name` | Имя Docker-сети для подключения контейнеров | string | Да |
| `topic_1min` | Название топика для 1-минутных данных | string | Да |
| `topic_5min` | Название топика для 5-минутных данных | string | Да |
| `kafka_admin_user` | Имя пользователя-администратора для Kafka | string | Да |
| `kafka_admin_password` | Пароль для пользователя-администратора Kafka | string (sensitive) | Да |
| `kafka_ssl_keystore_password` | Пароль для Keystore и Truststore Kafka | string (sensitive) | Да |
| `secrets_path` | Абсолютный путь к директории с секретами для Kafka | string | Да |
| `enable_kafka_acl` | Включить ACL авторизацию в Kafka | bool | Нет (default: false) |

---

## Доступ к сервисам

- **Zookeeper:** `localhost:2181`
- **Kafka Broker (внутренний):** `kafka:9092` (PLAINTEXT)
- **Kafka Broker (внешний):** `localhost:9093` (SASL_SSL)

### Подключение клиентов

**Для внутренних сервисов (в той же Docker-сети):**
```
bootstrap.servers=kafka:9092
security.protocol=PLAINTEXT
```

**Для внешних приложений:**
```
bootstrap.servers=localhost:9093
security.protocol=SASL_SSL
ssl.truststore.location=/path/to/kafka.truststore.jks
ssl.truststore.password=YOUR_KEYSTORE_PASSWORD
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="YOUR_ADMIN_USER" password="YOUR_ADMIN_PASSWORD";
```

---

## Создаваемые файлы

Модуль автоматически создает следующие файлы в директории `secrets_path`:

- `kafka.keystore.jks` - SSL keystore для сервера
- `kafka.truststore.jks` - SSL truststore для клиентов
- `kafka_server_jaas.conf` - JAAS конфигурация сервера
- `kafka_client.properties` - готовая конфигурация для внешних клиентов
- `kafka.env` - переменные окружения для приложений
- `kafka_keystore_creds`, `kafka_key_creds`, `kafka_truststore_creds` - файлы с паролями для SSL

---

## Устранение неполадок (Troubleshooting)

- **Контейнер Kafka не запускается:**
  - Проверьте логи контейнера: `docker logs kafka`
  - Убедитесь, что Zookeeper запущен и доступен
  - Проверьте, что SSL-сертификаты сгенерированы корректно в директории secrets

- **Ошибки SSL подключения:**
  - Убедитесь, что `kafka_ssl_keystore_password` соответствует паролю, использованному при генерации сертификатов
  - Проверьте, что файлы `kafka.keystore.jks` и `kafka.truststore.jks` существуют и доступны

- **Ошибки SASL аутентификации:**
  - Проверьте, что пользователь создан: `docker exec kafka kafka-configs --bootstrap-server kafka:9092 --describe --entity-type users`
  - Убедитесь, что используете правильные учетные данные из `terraform.tfvars`

- **Проблемы с созданием топиков:**
  - Скрипт настройки ждет готовности Kafka до 90 секунд
  - Проверьте логи: `docker logs kafka` для диагностики проблем с брокером
