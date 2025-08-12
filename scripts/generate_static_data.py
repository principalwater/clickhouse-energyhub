#!/usr/bin/env python3
"""
Скрипт для генерации статических данных в ClickHouse
"""

import sys
import os
sys.path.append(os.path.dirname(__file__))

from clickhouse_utils import execute_sql_script

def generate_devices_data():
    """Генерация данных об устройствах"""
    sql_script = """
    INSERT INTO raw.devices_raw (device_id, device_name, device_type, location_id, manufacturer, model, installation_date, last_maintenance_date, status, raw_data)
    SELECT 
        number as device_id,
        'Устройство ' || toString(number) as device_name,
        CASE 
            WHEN number % 3 = 0 THEN 'ГЭС'
            WHEN number % 3 = 1 THEN 'ТЭС'
            ELSE 'СЭС'
        END as device_type,
        (number % 10) + 1 as location_id,
        CASE 
            WHEN number % 3 = 0 THEN 'Росэнергомаш'
            WHEN number % 3 = 1 THEN 'Силовые машины'
            ELSE 'ТРТ'
        END as manufacturer,
        'Модель-' || toString(number) as model,
        addYears(toDate('2020-01-01'), number % 5) as installation_date,
        addDays(toDate('2024-01-01'), number % 30) as last_maintenance_date,
        'active' as status,
        '{}' as raw_data
    FROM numbers(1, 50);
    """
    
    result = execute_sql_script(sql_script)
    if result['success']:
        print(f"✅ Сгенерировано {result['result']} записей об устройствах")
    else:
        print(f"❌ Ошибка при генерации данных об устройствах: {result['error']}")
        raise Exception(result['error'])

def generate_locations_data():
    """Генерация данных о локациях"""
    sql_script = """
    INSERT INTO raw.locations_raw (location_id, location_name, region, city, address, latitude, longitude, timezone, country, raw_data)
    SELECT 
        number as location_id,
        'Регион ' || toString(number) as location_name,
        CASE 
            WHEN number % 4 = 0 THEN 'Центральный'
            WHEN number % 4 = 1 THEN 'Северо-Западный'
            WHEN number % 4 = 2 THEN 'Сибирский'
            ELSE 'Дальневосточный'
        END as region,
        'Город-' || toString(number) as city,
        'ул. Энергетиков, д. ' || toString(number) as address,
        round(rand() * 20 + 55, 4) as latitude,
        round(rand() * 40 + 30, 4) as longitude,
        'Europe/Moscow' as timezone,
        'Россия' as country,
        '{}' as raw_data
    FROM numbers(1, 10);
    """
    
    result = execute_sql_script(sql_script)
    if result['success']:
        print(f"✅ Сгенерировано {result['result']} записей о локациях")
    else:
        print(f"❌ Ошибка при генерации данных о локациях: {result['error']}")
        raise Exception(result['error'])

def generate_consumption_data():
    """Генерация данных о потреблении энергии"""
    sql_script = """
    INSERT INTO raw.energy_consumption_raw (device_id, location_id, timestamp, energy_kwh, voltage, current_amp, power_factor, temperature, humidity, raw_data)
    SELECT 
        number as device_id,
        (number % 10) + 1 as location_id,
        addHours(now(), -number) as timestamp,
        round(rand() * 1000 + 500, 2) as energy_kwh,
        round(rand() * 50 + 220, 2) as voltage,
        round(rand() * 100 + 10, 2) as current_amp,
        round(rand() * 0.3 + 0.7, 3) as power_factor,
        round(rand() * 30 + 20, 1) as temperature,
        round(rand() * 20 + 40, 1) as humidity,
        '{}' as raw_data
    FROM numbers(1, 100);
    """
    
    result = execute_sql_script(sql_script)
    if result['success']:
        print(f"✅ Сгенерировано {result['result']} записей о потреблении энергии")
    else:
        print(f"❌ Ошибка при генерации данных о потреблении: {result['error']}")
        raise Exception(result['error'])

def generate_weather_data():
    """Генерация данных о погоде"""
    sql_script = """
    INSERT INTO raw.raw_weather (weather_id, location_id, timestamp, temperature_c, humidity_percent, wind_speed_mps, precipitation_mm)
    SELECT 
        'WEATHER_' || toString(number) as weather_id,
        (number % 10) + 1 as location_id,
        addHours(now(), -number) as timestamp,
        round(rand() * 40 - 20, 1) as temperature_c,
        round(rand() * 100, 1) as humidity_percent,
        round(rand() * 20, 1) as wind_speed_mps,
        round(rand() * 50, 1) as precipitation_mm
    FROM numbers(1, 200)
    WHERE NOT EXISTS (
        SELECT 1 FROM raw.raw_weather WHERE weather_id = 'WEATHER_' || toString(number)
    );
    """
    
    result = execute_sql_script(sql_script)
    if result['success']:
        print(f"✅ Сгенерировано {result['result']} записей о погоде")
    else:
        print(f"❌ Ошибка при генерации данных о погоде: {result['error']}")
        raise Exception(result['error'])

def main():
    """Основная функция генерации всех статических данных"""
    print("🚀 Начало генерации статических данных...")
    
    try:
        # Генерируем данные в правильном порядке (сначала справочники)
        generate_locations_data()
        generate_devices_data()
        generate_consumption_data()
        generate_weather_data()
        
        print("✅ Все статические данные успешно сгенерированы!")
        
    except Exception as e:
        print(f"❌ Ошибка при генерации статических данных: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
