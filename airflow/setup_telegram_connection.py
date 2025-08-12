#!/usr/bin/env python3
"""
Скрипт для автоматического создания Telegram соединения в Airflow.
Использует переменные окружения для настройки.
"""

import os
import sys
from airflow import settings
from airflow.models import Connection
from sqlalchemy.exc import IntegrityError

def create_telegram_connection():
    """Создает Telegram соединение в Airflow."""
    
    # Получаем переменные окружения
    bot_token = os.environ.get('TELEGRAM_BOT_TOKEN')
    chat_id = os.environ.get('TELEGRAM_CHAT_ID')
    
    if not bot_token or not chat_id:
        print("❌ Переменные TELEGRAM_BOT_TOKEN или TELEGRAM_CHAT_ID не установлены")
        print(f"TELEGRAM_BOT_TOKEN: {'✅' if bot_token else '❌'}")
        print(f"TELEGRAM_CHAT_ID: {'✅' if chat_id else '❌'}")
        return False
    
    # Создаем соединение
    conn = Connection(
        conn_id='telegram_default',
        conn_type='telegram',
        host=chat_id,  # Chat ID идет в поле Host
        password=bot_token,  # Bot Token идет в поле Password
        description='Telegram соединение для уведомлений (создано автоматически)'
    )
    
    try:
        # Открываем сессию
        session = settings.Session()
        
        # Проверяем, существует ли уже соединение
        existing_conn = session.query(Connection).filter(
            Connection.conn_id == 'telegram_default'
        ).first()
        
        if existing_conn:
            print(f"🔄 Обновление существующего соединения telegram_default...")
            # Обновляем существующее соединение
            existing_conn.host = chat_id
            existing_conn.password = bot_token
            existing_conn.description = 'Telegram соединение для уведомлений (обновлено автоматически)'
        else:
            print(f"🆕 Создание нового соединения telegram_default...")
            # Добавляем новое соединение
            session.add(conn)
        
        # Сохраняем изменения
        session.commit()
        session.close()
        
        print("✅ Telegram соединение успешно настроено!")
        print(f"   Connection ID: telegram_default")
        print(f"   Chat ID: {chat_id}")
        print(f"   Bot Token: {bot_token[:10]}...{bot_token[-10:] if len(bot_token) > 20 else '***'}")
        
        return True
        
    except IntegrityError as e:
        print(f"❌ Ошибка при создании соединения: {e}")
        session.rollback()
        session.close()
        return False
    except Exception as e:
        print(f"❌ Неожиданная ошибка: {e}")
        if 'session' in locals():
            session.rollback()
            session.close()
        return False

def main():
    """Основная функция."""
    print("🔧 Настройка Telegram соединения в Airflow...")
    
    try:
        # Инициализируем Airflow
        from airflow import configuration
        configuration.load_test_config()
        
        # Создаем соединение
        success = create_telegram_connection()
        
        if success:
            print("🎉 Настройка завершена успешно!")
            sys.exit(0)
        else:
            print("💥 Настройка завершилась с ошибкой!")
            sys.exit(1)
            
    except Exception as e:
        print(f"❌ Критическая ошибка: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
