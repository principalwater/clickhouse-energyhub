import random
from datetime import datetime

# --- Справочные данные для генерации ---

RIVER_GES_MAPPING = {
    "Волга": ["Жигулёвская ГЭС", "Волжская ГЭС", "Саратовская ГЭС"],
    "Енисей": ["Саяно-Шушенская ГЭС", "Красноярская ГЭС", "Майнская ГЭС"],
    "Ангара": ["Братская ГЭС", "Усть-Илимская ГЭС", "Иркутская ГЭС"],
    "Амур": ["Зейская ГЭС", "Бурейская ГЭС"]
}

TRADING_ZONES = {
    "EU-RU": {"min_price": 25.0, "max_price": 55.0},
    "RU-KZ": {"min_price": 20.0, "max_price": 45.0},
    "SIBERIA": {"min_price": 15.0, "max_price": 35.0},
}

# --- Функции-генераторы ---

def generate_river_flow_data():
    """
    Генерирует одно сообщение с данными о речном стоке.
    """
    river = random.choice(list(RIVER_GES_MAPPING.keys()))
    ges = random.choice(RIVER_GES_MAPPING[river])
    
    return {
        "timestamp": datetime.utcnow().isoformat(),
        "river_name": river,
        "ges_name": ges,
        "water_level_m": round(random.uniform(100.0, 120.0), 2),  # Уровень воды в метрах
        "flow_rate_m3_s": round(random.uniform(1000.0, 5000.0), 2), # Расход воды, м³/с
        "power_output_mw": round(random.uniform(500.0, 2000.0), 2)  # Выработка, МВт
    }

def generate_market_data():
    """
    Генерирует одно сообщение с данными о торгах на бирже.
    """
    zone = random.choice(list(TRADING_ZONES.keys()))
    price_range = TRADING_ZONES[zone]
    
    return {
        "timestamp": datetime.utcnow().isoformat(),
        "trading_zone": zone,
        "price_eur_mwh": round(random.uniform(price_range["min_price"], price_range["max_price"]), 2),
        "volume_mwh": round(random.uniform(100.0, 1000.0), 2)
    }
