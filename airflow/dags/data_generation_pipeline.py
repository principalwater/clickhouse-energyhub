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
    'retry_delay': timedelta(minutes=1),
}

# Создание DAG для генерации данных речного стока
river_flow_dag = DAG(
    'river_flow_data_generation',
    default_args=default_args,
    description='Генерация данных речного стока каждую минуту',
    schedule='* * * * *',  # Каждую минуту
    catchup=False,
    tags=['river-flow', 'kafka', 'data-generation'],
)

def generate_river_flow_data():
    """Генерация данных речного стока и отправка в Kafka"""
    try:
        # Импортируем необходимые модули
        from generate_river_flow import main
        
        # Генерируем 1 сообщение с задержкой 0 секунд
        main(iterations=1, delay=0)
        
        print("✅ Данные речного стока успешно сгенерированы и отправлены в Kafka")
        return "Success"
    except Exception as e:
        print(f"❌ Ошибка при генерации данных речного стока: {e}")
        raise

def health_check_river_flow():
    """Проверка здоровья генератора данных речного стока"""
    print("🔍 Проверка здоровья генератора данных речного стока...")
    return "Healthy"

# Определение задач
generate_river_flow_task = PythonOperator(
    task_id='generate_river_flow_data',
    python_callable=generate_river_flow_data,
    dag=river_flow_dag,
)

health_check_task = PythonOperator(
    task_id='health_check',
    python_callable=health_check_river_flow,
    dag=river_flow_dag,
)

# Определение зависимостей
generate_river_flow_task >> health_check_task
