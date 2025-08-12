#!/usr/bin/env python3
"""
Клиент для работы с Nord Pool API
"""

import requests
import json
import time
from datetime import datetime, timedelta
import os
from dotenv import load_dotenv

# Load environment variables
dotenv_path = os.path.join(os.path.dirname(__file__), '../infra/env/kafka.env')
load_dotenv(dotenv_path=dotenv_path)

class NordPoolAPIClient:
    """
    Клиент для работы с Nord Pool API
    """
    
    def __init__(self):
        self.base_url = "https://api.nordpoolgroup.com"
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'EnergyHub/1.0',
            'Accept': 'application/json'
        })
    
    def get_intraday_prices(self, area: str = "FI", date: str = None):
        """
        Получение внутридневных цен
        
        Args:
            area (str): Торговая зона (FI, SE, NO, DK, etc.)
            date (str): Дата в формате YYYY-MM-DD
        
        Returns:
            dict: Данные о ценах
        """
        if not date:
            date = datetime.now().strftime("%Y-%m-%d")
        
        url = f"{self.base_url}/v1/intraday/prices"
        params = {
            'area': area,
            'date': date
        }
        
        try:
            response = self.session.get(url, params=params, timeout=30)
            response.raise_for_status()
            
            data = response.json()
            print(f"✅ Получены данные о ценах для зоны {area} на {date}")
            return data
            
        except requests.exceptions.RequestException as e:
            print(f"❌ Ошибка при получении данных от Nord Pool API: {e}")
            return None
    
    def get_day_ahead_prices(self, area: str = "FI", date: str = None):
        """
        Получение дневных цен
        
        Args:
            area (str): Торговая зона
            date (str): Дата в формате YYYY-MM-DD
        
        Returns:
            dict: Данные о ценах
        """
        if not date:
            date = datetime.now().strftime("%Y-%m-%d")
        
        url = f"{self.base_url}/v1/dayahead/prices"
        params = {
            'area': area,
            'date': date
        }
        
        try:
            response = self.session.get(url, params=params, timeout=30)
            response.raise_for_status()
            
            data = response.json()
            print(f"✅ Получены дневные цены для зоны {area} на {date}")
            return data
            
        except requests.exceptions.RequestException as e:
            print(f"❌ Ошибка при получении дневных цен: {e}")
            return None
    
    def get_volume_data(self, area: str = "FI", date: str = None):
        """
        Получение данных об объемах торгов
        
        Args:
            area (str): Торговая зона
            date (str): Дата в формате YYYY-MM-DD
        
        Returns:
            dict: Данные об объемах
        """
        if not date:
            date = datetime.now().strftime("%Y-%m-%d")
        
        url = f"{self.base_url}/v1/volumes"
        params = {
            'area': area,
            'date': date
        }
        
        try:
            response = self.session.get(url, params=params, timeout=30)
            response.raise_for_status()
            
            data = response.json()
            print(f"✅ Получены данные об объемах для зоны {area} на {date}")
            return data
            
        except requests.exceptions.RequestException as e:
            print(f"❌ Ошибка при получении данных об объемах: {e}")
            return None
    
    def transform_to_market_data(self, api_data: dict, area: str):
        """
        Трансформация данных API в формат рыночных данных
        
        Args:
            api_data (dict): Данные от API
            area (str): Торговая зона
        
        Returns:
            list: Список рыночных данных
        """
        market_data = []
        
        if not api_data or 'data' not in api_data:
            return market_data
        
        try:
            for item in api_data['data']:
                market_record = {
                    "timestamp": datetime.utcnow().isoformat(),
                    "trading_zone": area,
                    "price_eur_mwh": float(item.get('price', 0)),
                    "volume_mwh": float(item.get('volume', 0)),
                    "source": "nordpool_api"
                }
                market_data.append(market_record)
            
            print(f"✅ Трансформировано {len(market_data)} записей рыночных данных")
            
        except Exception as e:
            print(f"❌ Ошибка при трансформации данных: {e}")
        
        return market_data

def generate_fallback_market_data():
    """
    Генерация резервных рыночных данных (если API недоступен)
    
    Returns:
        dict: Резервные рыночные данные
    """
    import random
    from datetime import datetime
    
    trading_zones = ["FI", "SE", "NO", "DK", "EE", "LV", "LT"]
    zone = random.choice(trading_zones)
    
    return {
        "timestamp": datetime.utcnow().isoformat(),
        "trading_zone": zone,
        "price_eur_mwh": round(random.uniform(25.0, 55.0), 2),
        "volume_mwh": round(random.uniform(100.0, 1000.0), 2),
        "source": "fallback_generator"
    }

def main():
    """Основная функция для тестирования API клиента"""
    client = NordPoolAPIClient()
    
    # Тестируем получение данных
    print("🧪 Тестирование Nord Pool API клиента...")
    
    # Получаем внутридневные цены
    intraday_data = client.get_intraday_prices("FI")
    if intraday_data:
        market_data = client.transform_to_market_data(intraday_data, "FI")
        print(f"Получено {len(market_data)} записей внутридневных данных")
    
    # Получаем дневные цены
    day_ahead_data = client.get_day_ahead_prices("FI")
    if day_ahead_data:
        market_data = client.transform_to_market_data(day_ahead_data, "FI")
        print(f"Получено {len(market_data)} записей дневных данных")
    
    print("✅ Тестирование завершено")

if __name__ == "__main__":
    main()
