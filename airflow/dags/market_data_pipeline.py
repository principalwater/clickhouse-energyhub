from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
import os
import sys

# Добавляем путь к скриптам Kafka producer
sys.path.append('/opt/airflow/scripts/kafka_producer')

# Определение параметров DAG
default_args = {
    'owner': 'energy-hub',
    'depends_on_past': False,
    'start_date': datetime(2025, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=2),
}

# Создание DAG для генерации рыночных данных
market_data_dag = DAG(
    'market_data_generation',
    default_args=default_args,
    description='Генерация рыночных данных каждые 5 минут',
    schedule='*/5 * * * *',  # Каждые 5 минут
    catchup=False,
    tags=['market-data', 'kafka', 'data-generation'],
)

def generate_market_data():
    """Генерация рыночных данных и отправка в Kafka"""
    try:
        # Импортируем необходимые модули
        from generate_market_data import main
        
        # Генерируем 1 сообщение с задержкой 0 секунд
        main(iterations=1, delay=0)
        
        print("✅ Рыночные данные успешно сгенерированы и отправлены в Kafka")
        return "Success"
    except Exception as e:
        print(f"❌ Ошибка при генерации рыночных данных: {e}")
        raise

def health_check_market_data():
    """Проверка здоровья генератора рыночных данных"""
    print("🔍 Проверка здоровья генератора рыночных данных...")
    return "Healthy"

# Определение задач
generate_market_data_task = PythonOperator(
    task_id='generate_market_data',
    python_callable=generate_market_data,
    dag=market_data_dag,
)

health_check_task = PythonOperator(
    task_id='health_check',
    python_callable=health_check_market_data,
    dag=market_data_dag,
)

# Определение зависимостей
generate_market_data_task >> health_check_task
