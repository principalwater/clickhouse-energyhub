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
    INSERT INTO raw.raw_devices (device_id, device_name, device_type, location_id, capacity_mw, installation_date, status)
    SELECT 
        'DEV_' || toString(number) as device_id,
        'Устройство ' || toString(number) as device_name,
        CASE 
            WHEN number % 3 = 0 THEN 'ГЭС'
            WHEN number % 3 = 1 THEN 'ТЭС'
            ELSE 'СЭС'
        END as device_type,
        (number % 10) + 1 as location_id,
        round(rand() * 1000 + 100, 2) as capacity_mw,
        addYears(toDate('2020-01-01'), number % 5) as installation_date,
        'active' as status
    FROM numbers(1, 50)
    WHERE NOT EXISTS (
        SELECT 1 FROM raw.raw_devices WHERE device_id = 'DEV_' || toString(number)
    );
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
    INSERT INTO raw.raw_locations (location_id, location_name, region, latitude, longitude, timezone)
    SELECT 
        number as location_id,
        'Регион ' || toString(number) as location_name,
        CASE 
            WHEN number % 4 = 0 THEN 'Центральный'
            WHEN number % 4 = 1 THEN 'Северо-Западный'
            WHEN number % 4 = 2 THEN 'Сибирский'
            ELSE 'Дальневосточный'
        END as region,
        round(rand() * 20 + 55, 4) as latitude,
        round(rand() * 40 + 30, 4) as longitude,
        'Europe/Moscow' as timezone
    FROM numbers(1, 10)
    WHERE NOT EXISTS (
        SELECT 1 FROM raw.raw_locations WHERE location_id = number
    );
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
    INSERT INTO raw.raw_energy_consumption (consumption_id, location_id, timestamp, consumption_mwh, peak_load_mw, avg_load_mw)
    SELECT 
        'CONS_' || toString(number) as consumption_id,
        (number % 10) + 1 as location_id,
        addHours(now(), -number) as timestamp,
        round(rand() * 1000 + 500, 2) as consumption_mwh,
        round(rand() * 500 + 200, 2) as peak_load_mw,
        round(rand() * 300 + 150, 2) as avg_load_mw
    FROM numbers(1, 100)
    WHERE NOT EXISTS (
        SELECT 1 FROM raw.raw_energy_consumption WHERE consumption_id = 'CONS_' || toString(number)
    );
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
