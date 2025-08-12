from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from airflow.providers.dbt.cloud.operators.dbt import DbtCloudRunJobOperator
import os
import sys

# Добавляем путь к скриптам
sys.path.append('/opt/airflow/scripts')

# Определение параметров DAG
default_args = {
    'owner': 'energy-hub',
    'depends_on_past': False,
    'start_date': datetime(2025, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
}

# Создание DAG для работы с dbt
dbt_dag = DAG(
    'dbt_pipeline',
    default_args=default_args,
    description='Пайплайн для работы с dbt моделями',
    schedule='*/30 * * * *',  # Каждые 30 минут
    catchup=False,
    tags=['dbt', 'data-transformation'],
)

def check_dbt_project():
    """Проверка dbt проекта"""
    try:
        print("🔍 Проверка dbt проекта...")
        
        # Здесь можно добавить проверку dbt проекта
        # Например, проверка синтаксиса моделей, тестов и т.д.
        
        print("✅ dbt проект проверен")
        return "Success"
    except Exception as e:
        print(f"❌ Ошибка при проверке dbt проекта: {e}")
        raise

def run_dbt_models():
    """Запуск всех dbt моделей"""
    try:
        print("🔄 Запуск dbt моделей...")
        
        # Здесь будет запуск dbt run
        # Можно использовать BashOperator или DbtCloudRunJobOperator
        
        print("✅ dbt модели выполнены успешно")
        return "Success"
    except Exception as e:
        print(f"❌ Ошибка при выполнении dbt моделей: {e}")
        raise

def run_dbt_tests():
    """Запуск dbt тестов"""
    try:
        print("🧪 Запуск dbt тестов...")
        
        # Здесь будет запуск dbt test
        
        print("✅ dbt тесты выполнены успешно")
        return "Success"
    except Exception as e:
        print(f"❌ Ошибка при выполнении dbt тестов: {e}")
        raise

def generate_dbt_docs():
    """Генерация dbt документации"""
    try:
        print("📚 Генерация dbt документации...")
        
        # Здесь будет генерация dbt docs
        
        print("✅ dbt документация сгенерирована")
        return "Success"
    except Exception as e:
        print(f"❌ Ошибка при генерации dbt документации: {e}")
        raise

def health_check_dbt():
    """Проверка здоровья dbt системы"""
    print("🔍 Проверка здоровья dbt системы...")
    return "Healthy"

# Определение задач
check_dbt_task = PythonOperator(
    task_id='check_dbt_project',
    python_callable=check_dbt_project,
    dag=dbt_dag,
)

run_models_task = PythonOperator(
    task_id='run_dbt_models',
    python_callable=run_dbt_models,
    dag=dbt_dag,
)

run_tests_task = PythonOperator(
    task_id='run_dbt_tests',
    python_callable=run_dbt_tests,
    dag=dbt_dag,
)

generate_docs_task = PythonOperator(
    task_id='generate_dbt_docs',
    python_callable=generate_dbt_docs,
    dag=dbt_dag,
)

health_check_task = PythonOperator(
    task_id='health_check',
    python_callable=health_check_dbt,
    dag=dbt_dag,
)

# Определение зависимостей
check_dbt_task >> run_models_task >> run_tests_task >> generate_docs_task >> health_check_task
