# 📱 Современная настройка Telegram алертинга в Airflow

Простое решение для отправки уведомлений в Telegram из Apache Airflow через переменные окружения.

## 🏗️ Архитектура

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Airflow DAG   │───▶│ TelegramOperator │───▶│  Telegram Bot   │
│                 │    │                  │    │                 │
│ • Tasks         │    │ • Send Message   │    │ • Send to Chat  │
│ • Notifications │    │ • Format Text    │    │ • Parse Mode    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 📋 Требования

- Apache Airflow >= 2.8.0 (использует новый синтаксис `schedule`)
- Python >= 3.8
- apache-airflow-providers-telegram >= 4.8.2
- Telegram Bot Token
- Telegram Chat ID

## 🚀 Быстрая настройка

### Шаг 1: Создание Telegram Bot
1. Найдите @BotFather в Telegram
2. Отправьте `/newbot`
3. Следуйте инструкциям для создания бота
4. Сохраните полученный Bot Token

### Шаг 2: Получение Chat ID

**Для личного чата:**
1. Найдите @userinfobot в Telegram
2. Отправьте любое сообщение
3. Скопируйте ваш Chat ID

**Для группы/канала:**
Предположим, что имя вашего бота `my_bot`.

1. **Добавьте бота в группу:**
   - Перейдите в группу
   - Нажмите на название группы
   - Нажмите "Добавить участников"
   - В поиске найдите вашего бота: `@my_bot`
   - Выберите бота и нажмите "Добавить"

2. **Отправьте тестовое сообщение боту:**
   - Отправьте в группу сообщение: `/my_id @my_bot`
   - (Сообщение должно начинаться с `/` для корректной работы)

3. **Получите Chat ID через API:**
   - Перейдите по ссылке: `https://api.telegram.org/botXXX:YYYY/getUpdates`
   - Замените `XXX:YYYY` на ваш Bot Token

4. **Найдите Chat ID:**
   - Найдите в ответе: `"chat":{"id":-zzzzzzzzzz,`
   - `-zzzzzzzzzz` это ваш Chat ID (с минусом)

5. **Тестирование (опционально):**
   ```bash
   curl -X POST "https://api.telegram.org/botXXX:YYYY/sendMessage" \
        -d "chat_id=-zzzzzzzzzz&text=Тестовое сообщение"
   ```

### Шаг 3: Настройка через Terraform (рекомендуется)
Добавьте в ваш `terraform.tfvars` файл:
```hcl
# Telegram Bot Configuration
telegram_bot_token = "YOUR_BOT_TOKEN_HERE"  # Получите у @BotFather
telegram_chat_id   = "YOUR_CHAT_ID_HERE"   # Получите у @userinfobot
```

### Шаг 4: Альтернативно - через переменные окружения
```bash
export TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN_HERE"
export TELEGRAM_CHAT_ID="YOUR_CHAT_ID_HERE"
```

### Шаг 5: Развертывание
```bash
cd infra/terraform
terraform apply
```

## 🔧 Использование в DAG'ах

### Настройка переменных в начале файла
```python
import os
from airflow.providers.telegram.operators.telegram import TelegramOperator

# Переменные окружения для Telegram
TELEGRAM_BOT_TOKEN = os.environ.get('TELEGRAM_BOT_TOKEN')
TELEGRAM_CHAT_ID = os.environ.get('TELEGRAM_CHAT_ID')
```

### Простое уведомление
```python
with DAG('my_dag') as dag:
    notification = TelegramOperator(
        task_id='send_notification',
        token=TELEGRAM_BOT_TOKEN,      # Переменная окружения
        chat_id=TELEGRAM_CHAT_ID,      # Переменная окружения
        text="🎉 Task completed!",
        parse_mode='Markdown',
    )
```

### Уведомления после выполнения задач
```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.telegram.operators.telegram import TelegramOperator

with DAG('my_dag') as dag:
    # Основная задача
    task = PythonOperator(
        task_id='my_task',
        python_callable=lambda: print("Hello World")
    )
    
    # Уведомление об успехе
    success_notification = TelegramOperator(
        task_id='success_notification',
        token=TELEGRAM_BOT_TOKEN,
        chat_id=TELEGRAM_CHAT_ID,
        text="✅ Task completed successfully!",
        parse_mode='Markdown',
    )
    
    # Зависимости
    task >> success_notification
```

### Условные уведомления с проверкой
```python
# Проверка доступности Telegram
TELEGRAM_AVAILABLE = bool(TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID)

with DAG('my_dag') as dag:
    task = PythonOperator(
        task_id='my_task',
        python_callable=lambda: print("Task executed")
    )
    
    # Уведомления только если Telegram настроен
    if TELEGRAM_AVAILABLE:
        success_notification = TelegramOperator(
            task_id='success_notification',
            token=TELEGRAM_BOT_TOKEN,
            chat_id=TELEGRAM_CHAT_ID,
            text="✅ Task completed",
            parse_mode='Markdown',
        )
        
        task >> success_notification
```

## 📱 Форматы сообщений

### Markdown
```python
text="**Bold text**\n*Italic text*\n`Code`\n[Link](https://example.com)"
parse_mode='Markdown'
```

### HTML
```python
text="<b>Bold text</b>\n<i>Italic text</i>\n<code>Code</code>"
parse_mode='HTML'
```

### Обычный текст
```python
text="Simple text without formatting"
parse_mode=None
```

## 🧪 Тестирование

### Запуск тестового DAG
1. Включите DAG `telegram_monitoring_prod` в Airflow UI
2. Или запустите через CLI: `airflow dags trigger telegram_monitoring_prod`

### Проверка переменных окружения
```bash
# В контейнере Airflow проверьте:
docker exec airflow-scheduler env | grep TELEGRAM
```

## 🚨 Устранение неполадок

### "TelegramOperator not available"
```bash
pip install apache-airflow-providers-telegram>=4.8.2
```

### "Telegram переменные окружения не настроены"
1. Проверьте настройки в `terraform.tfvars`
2. Пересоздайте контейнеры: `terraform apply`

### "Message not sent"
1. Проверьте корректность Bot Token
2. Убедитесь, что бот добавлен в чат/канал
3. Проверьте права бота в чате

### "Token validation failed"
1. Получите новый токен у @BotFather
2. Обновите переменную `telegram_bot_token` в tfvars
3. Перезапустите: `terraform apply`

## 📚 Готовые DAG'ы в проекте

В проекте уже есть готовые примеры:
- `telegram_monitoring_prod` - продакшн мониторинг (каждые 30 мин)
- `telegram_manual_report` - ручной запуск отчетов

## 🎯 Преимущества нового подхода

✅ **Через переменные окружения** - безопасно и просто  
✅ **Интеграция с Terraform** - автоматизированное развертывание  
✅ **Без connections** - не нужно настраивать в Airflow UI  
✅ **Простота обновления** - изменения только в tfvars  
✅ **Безопасность** - креды не попадают в код или UI  
✅ **Московское время** - все временные метки в UTC+3 (Europe/Moscow)  

---

**⭐ Простое и эффективное решение для Telegram алертинга!**
