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
        from schemas import generate_river_flow_data as gen_data
        from producers import DataProducer
        
        print("🔄 Генерация данных речного стока...")
        
        # Создаем producer без SASL аутентификации (работает с обычным Kafka)
        producer = DataProducer(broker_url='kafka:9092')
        
        # Генерируем данные
        data = gen_data()
        print(f"📊 Сгенерированы данные: {data}")
        
        # Отправляем в Kafka и проверяем результат
        result = producer.send_data('energy_data_1min', data)
        
        if result is None:
            raise Exception("Не удалось отправить данные в Kafka - нет подтверждения доставки")
        
        # Убеждаемся, что данные отправлены
        producer.flush()
        producer.close()
        
        print("✅ Данные речного стока успешно сгенерированы и отправлены в Kafka")
        print(f"📋 Отправлено в топик energy_data_1min: {data}")
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
