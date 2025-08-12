from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator

# Определение параметров DAG
default_args = {
    'owner': 'energy-hub',
    'depends_on_past': False,
    'start_date': datetime(2025, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# Создание DAG
dag = DAG(
    'energy_data_pipeline',
    default_args=default_args,
    description='Pipeline обработки энергетических данных',
    schedule=timedelta(hours=1),
    catchup=False,
    tags=['energy', 'kafka', 'clickhouse'],
)

def extract_data(**context):
    """Извлечение данных из источников"""
    print("🔄 Извлечение данных из Kafka...")
    # Здесь будет логика извлечения данных из Kafka
    return "Data extracted successfully"

def transform_data(**context):
    """Трансформация данных"""
    print("🔄 Трансформация данных...")
    # Здесь будет логика трансформации данных
    return "Data transformed successfully"

def load_data(**context):
    """Загрузка данных в ClickHouse"""
    print("🔄 Загрузка данных в ClickHouse...")
    # Здесь будет логика загрузки данных в ClickHouse
    return "Data loaded successfully"

# Определение задач
extract_task = PythonOperator(
    task_id='extract_data',
    python_callable=extract_data,
    dag=dag,
)

transform_task = PythonOperator(
    task_id='transform_data',
    python_callable=transform_data,
    dag=dag,
)

load_task = PythonOperator(
    task_id='load_data',
    python_callable=load_data,
    dag=dag,
)

health_check = BashOperator(
    task_id='health_check',
    bash_command='echo "✅ Energy Hub pipeline is healthy"',
    dag=dag,
)

# Определение зависимостей задач
extract_task >> transform_task >> load_task >> health_check
