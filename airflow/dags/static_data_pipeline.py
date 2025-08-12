from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
import os
import sys

# Определение параметров DAG
default_args = {
    'owner': 'energy-hub',
    'depends_on_past': False,
    'start_date': datetime(2025, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 3,
    'retry_delay': timedelta(minutes=10),
}

# Создание DAG для генерации статических данных
static_data_dag = DAG(
    'static_data_generation',
    default_args=default_args,
    description='Генерация статических данных раз в день',
    schedule='0 2 * * *',  # Каждый день в 2:00
    catchup=False,
    tags=['static-data', 'clickhouse', 'data-generation'],
)

def generate_static_devices():
    """Генерация статических данных об устройствах"""
    try:
        # Импортируем и запускаем скрипт генерации
        import sys
        import os
        sys.path.append('/opt/airflow/scripts')
        
        from generate_static_data import generate_devices_data
        generate_devices_data()
        
        print("✅ Статические данные об устройствах сгенерированы")
        return "Success"
    except Exception as e:
        print(f"❌ Ошибка при генерации данных об устройствах: {e}")
        raise

def generate_static_locations():
    """Генерация статических данных о локациях"""
    try:
        # Импортируем и запускаем скрипт генерации
        import sys
        sys.path.append('/opt/airflow/scripts')
        
        from generate_static_data import generate_locations_data
        generate_locations_data()
        
        print("✅ Статические данные о локациях сгенерированы")
        return "Success"
    except Exception as e:
        print(f"❌ Ошибка при генерации данных о локациях: {e}")
        raise

def generate_static_consumption():
    """Генерация статических данных о потреблении энергии"""
    try:
        # Импортируем и запускаем скрипт генерации
        import sys
        sys.path.append('/opt/airflow/scripts')
        
        from generate_static_data import generate_consumption_data
        generate_consumption_data()
        
        print("✅ Статические данные о потреблении энергии сгенерированы")
        return "Success"
    except Exception as e:
        print(f"❌ Ошибка при генерации данных о потреблении: {e}")
        raise

def health_check_static_data():
    """Проверка здоровья генератора статических данных"""
    print("🔍 Проверка здоровья генератора статических данных...")
    return "Healthy"

# Определение задач
generate_devices_task = PythonOperator(
    task_id='generate_static_devices',
    python_callable=generate_static_devices,
    dag=static_data_dag,
)

generate_locations_task = PythonOperator(
    task_id='generate_static_locations',
    python_callable=generate_static_locations,
    dag=static_data_dag,
)

generate_consumption_task = PythonOperator(
    task_id='generate_static_consumption',
    python_callable=generate_static_consumption,
    dag=static_data_dag,
)

health_check_task = PythonOperator(
    task_id='health_check',
    python_callable=health_check_static_data,
    dag=static_data_dag,
)

# Определение зависимостей (параллельное выполнение)
[generate_devices_task, generate_locations_task] >> generate_consumption_task >> health_check_task
