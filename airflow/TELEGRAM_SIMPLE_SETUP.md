# 📱 Простая настройка Telegram алертинга в Airflow

Простое решение для отправки уведомлений в Telegram из Apache Airflow без плагинов.

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
- Telegram Bot Token
- Telegram Chat ID

## 🚀 Быстрая настройка

### Шаг 1: Установка провайдера
```bash
pip install apache-airflow-providers-telegram>=4.8.2
```

### Шаг 2: Создание Telegram Bot
1. Найдите @BotFather в Telegram
2. Отправьте `/newbot`
3. Следуйте инструкциям
4. Сохраните Bot Token

### Шаг 3: Получение Chat ID
1. Найдите @userinfobot в Telegram
2. Добавьте в нужный чат/канал
3. Отправьте любое сообщение
4. Скопируйте Chat ID

### Шаг 4: Настройка переменных
```bash
export TELEGRAM_BOT_TOKEN="123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
export TELEGRAM_CHAT_ID="-1001234567890"
```

### Шаг 5: Настройка Airflow Connection
```bash
cd airflow
python setup_telegram.py
```

### Шаг 6: Установка переменной Airflow
В Airflow UI: **Admin** → **Variables** → **+**
- Key: `telegram_chat_id`
- Value: `-1001234567890`

### Шаг 7: Перезапуск Airflow
```bash
airflow webserver stop
airflow scheduler stop
airflow webserver start -d
airflow scheduler start -d
```

## 🔧 Использование в DAG'ах

### Простое уведомление
```python
from airflow.providers.telegram.operators.telegram import TelegramOperator

with DAG('my_dag') as dag:
    notification = TelegramOperator(
        task_id='send_notification',
        telegram_conn_id='telegram_default',
        chat_id='{{ var.value.telegram_chat_id }}',
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
        telegram_conn_id='telegram_default',
        chat_id='{{ var.value.telegram_chat_id }}',
        text="✅ Task completed successfully!",
        parse_mode='Markdown',
    )
    
    # Зависимости
    task >> success_notification
```

### Уведомления о разных событиях
```python
with DAG('my_dag') as dag:
    # Задача
    task = PythonOperator(
        task_id='my_task',
        python_callable=lambda: print("Task executed")
    )
    
    # Уведомления
    start_notification = TelegramOperator(
        task_id='start_notification',
        telegram_conn_id='telegram_default',
        chat_id='{{ var.value.telegram_chat_id }}',
        text="🚀 DAG started",
        parse_mode='Markdown',
    )
    
    success_notification = TelegramOperator(
        task_id='success_notification',
        telegram_conn_id='telegram_default',
        chat_id='{{ var.value.telegram_chat_id }}',
        text="✅ Task completed",
        parse_mode='Markdown',
    )
    
    # Зависимости
    start_notification >> task >> success_notification
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
1. Включите DAG `telegram_alerting_demo` в Airflow UI
2. Или запустите через CLI: `airflow dags trigger telegram_alerting_demo`

### Проверка соединения
В Airflow UI: **Admin** → **Connections** → `telegram_default`

### Проверка переменных
В Airflow UI: **Admin** → **Variables** → `telegram_chat_id`

## 🚨 Устранение неполадок

### "TelegramOperator not available"
```bash
pip install apache-airflow-providers-telegram>=4.8.2
```

### "Connection not found"
```bash
python setup_telegram.py
```

### "Variable not found"
Создайте переменную `telegram_chat_id` в Airflow UI

### "Message not sent"
Проверьте права бота и добавление в чат

## 📚 Примеры DAG'ов

В проекте уже есть готовые примеры:
- `telegram_alerting_demo` - основной демо DAG
- `telegram_manual_notifications` - ручные уведомления
- `telegram_message_formats` - тест форматов сообщений

## 🎯 Преимущества простого подхода

✅ **Без плагинов** - используем только официальные компоненты  
✅ **Простота** - минимум кода и настроек  
✅ **Надежность** - официальная поддержка Apache Airflow  
✅ **Гибкость** - легко интегрировать в любые DAG'и  
✅ **Масштабируемость** - стандартный подход Airflow  

---

**⭐ Простое и эффективное решение для Telegram алертинга!**
