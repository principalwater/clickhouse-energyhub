#!/bin/bash

# Скрипт для автоматической генерации Keystore и Truststore для Kafka TLS
# Вызывается из Terraform и использует Docker, чтобы не требовать локальной установки Java/keytool.

set -e

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Ошибка: Недостаточно аргументов."
  echo "Использование: $0  "
  exit 1
fi

# Определяем абсолютные пути для надежности
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
SECRETS_DIR="$PROJECT_ROOT/infra/secrets"
KEYSTORE_FILE="$SECRETS_DIR/kafka.keystore.jks"

PASSWORD=$1
IMAGE_NAME="confluentinc/cp-kafka:$2"

# Создаем директорию для секретов, если ее нет
mkdir -p "$SECRETS_DIR"

# Проверяем, существует ли уже keystore. Если да, то удаляем для пересоздания
if [ -f "$KEYSTORE_FILE" ]; then
  echo "Удаляем старые сертификаты для пересоздания..."
  rm -f "$SECRETS_DIR"/kafka.keystore.jks "$SECRETS_DIR"/kafka.truststore.jks
fi

cd "$PROJECT_ROOT"

echo "Использование Docker-образа: $IMAGE_NAME"
echo "Загрузка Docker-образа... (это может занять время, если его нет локально)"
docker pull $IMAGE_NAME > /dev/null

echo "Генерация Keystore и Truststore с поддержкой нескольких хостов..."

# Запускаем keytool внутри временного Docker-контейнера
docker run --rm -v "$SECRETS_DIR":/tmp/secrets --workdir /tmp/secrets $IMAGE_NAME \
  bash -c " \
    echo 'Генерация Keystore с SAN...' && \
    keytool -genkeypair -alias kafka -keyalg RSA -keystore kafka.keystore.jks \
      -dname 'CN=kafka,OU=dev,O=energyhub,L=Moscow,S=Moscow,C=RU' \
      -ext SAN=DNS:kafka,DNS:localhost,IP:127.0.0.1 \
      -storepass $PASSWORD -keypass $PASSWORD -keysize 2048 -validity 365 && \
    \
    echo 'Экспорт сертификата...' && \
    keytool -exportcert -alias kafka -keystore kafka.keystore.jks -rfc -file kafka.cer -storepass $PASSWORD && \
    \
    echo 'Импорт сертификата в Truststore...' && \
    keytool -importcert -alias kafka -file kafka.cer -keystore kafka.truststore.jks -storepass $PASSWORD -noprompt && \
    \
    echo 'Очистка временного сертификата...' && \
    rm kafka.cer && \
    \
    echo 'Готово! Файлы kafka.keystore.jks и kafka.truststore.jks созданы с поддержкой kafka, localhost и 127.0.0.1.' \
  "

if [ $? -eq 0 ]; then
  echo "\nСертификаты успешно сгенерированы с поддержкой множественных хостов."
else
  echo "\nПроизошла ошибка при генерации сертификатов."
fi
