#!/usr/bin/env python3
"""
Тестовый скрипт для проверки настройки Airflow и зависимостей
"""

import sys
import os

def test_imports():
    """Тестирование импорта всех необходимых модулей"""
    print("🧪 Тестирование импорта модулей...")
    
    try:
        import clickhouse_connect
        print("✅ clickhouse-connect импортирован успешно")
    except ImportError as e:
        print(f"❌ Ошибка импорта clickhouse-connect: {e}")
        return False
    
    try:
        from dotenv import load_dotenv
        print("✅ python-dotenv импортирован успешно")
    except ImportError as e:
        print(f"❌ Ошибка импорта python-dotenv: {e}")
        return False
    
    try:
        import requests
        print("✅ requests импортирован успешно")
    except ImportError as e:
        print(f"❌ Ошибка импорта requests: {e}")
        return False
    
    try:
        from kafka import KafkaProducer
        print("✅ kafka-python импортирован успешно")
    except ImportError as e:
        print(f"❌ Ошибка импорта kafka-python: {e}")
        return False
    
    return True

def test_clickhouse_utils():
    """Тестирование утилит ClickHouse"""
    print("\n🧪 Тестирование утилит ClickHouse...")
    
    try:
        from clickhouse_utils import ClickHouseClient
        print("✅ ClickHouseClient импортирован успешно")
        
        # Проверяем, что можем создать клиент (без подключения)
        client = ClickHouseClient()
        print("✅ ClickHouseClient создан успешно")
        
    except Exception as e:
        print(f"❌ Ошибка при тестировании ClickHouse утилит: {e}")
        return False
    
    return True

def test_kafka_producer():
    """Тестирование Kafka producer"""
    print("\n🧪 Тестирование Kafka producer...")
    
    try:
        sys.path.append('/opt/airflow/scripts/kafka_producer')
        from producers import DataProducer
        print("✅ DataProducer импортирован успешно")
        
    except Exception as e:
        print(f"❌ Ошибка при тестировании Kafka producer: {e}")
        return False
    
    return True

def test_static_data_generator():
    """Тестирование генератора статических данных"""
    print("\n🧪 Тестирование генератора статических данных...")
    
    try:
        from generate_static_data import generate_devices_data, generate_locations_data
        print("✅ Функции генерации статических данных импортированы успешно")
        
    except Exception as e:
        print(f"❌ Ошибка при тестировании генератора статических данных: {e}")
        return False
    
    return True

def test_nordpool_api():
    """Тестирование Nord Pool API клиента"""
    print("\n🧪 Тестирование Nord Pool API клиента...")
    
    try:
        from nordpool_api_client import NordPoolAPIClient, generate_fallback_market_data
        print("✅ Nord Pool API клиент импортирован успешно")
        
        # Тестируем резервный генератор
        fallback_data = generate_fallback_market_data()
        print(f"✅ Резервный генератор создал данные: {fallback_data}")
        
    except Exception as e:
        print(f"❌ Ошибка при тестировании Nord Pool API клиента: {e}")
        return False
    
    return True

def main():
    """Основная функция тестирования"""
    print("🚀 Начало тестирования настройки Airflow...")
    
    tests = [
        test_imports,
        test_clickhouse_utils,
        test_kafka_producer,
        test_static_data_generator,
        test_nordpool_api
    ]
    
    passed = 0
    total = len(tests)
    
    for test in tests:
        if test():
            passed += 1
        else:
            print(f"❌ Тест {test.__name__} не прошел")
    
    print(f"\n📊 Результаты тестирования: {passed}/{total} тестов прошли успешно")
    
    if passed == total:
        print("✅ Все тесты прошли успешно! Airflow готов к работе.")
        return 0
    else:
        print("❌ Некоторые тесты не прошли. Проверьте установку зависимостей.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
