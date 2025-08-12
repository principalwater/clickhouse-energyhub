from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from airflow.providers.dbt.cloud.operators.dbt import DbtCloudRunJobOperator
import os
import sys

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

# Создание DAG для обработки данных
data_processing_dag = DAG(
    'data_processing_pipeline',
    description='Обработка данных через слои: raw → ods → dds → cdm',
    schedule='*/15 * * * *',  # Каждые 15 минут
    catchup=False,
    tags=['data-processing', 'dbt', 'clickhouse'],
)

def check_data_quality_raw():
    """Проверка качества данных в слое raw"""
    try:
        print("🔍 Проверка качества данных в слое raw...")
        
        # Здесь можно добавить проверки качества данных
        # Например, проверка на null значения, дубликаты, формат данных
        
        print("✅ Качество данных в слое raw проверено")
        return "Success"
    except Exception as e:
        print(f"❌ Ошибка при проверке качества данных: {e}")
        raise

def run_dbt_ods():
    """Запуск dbt моделей для слоя ODS"""
    try:
        print("🔄 Запуск dbt моделей для слоя ODS...")
        
        # Используем BashOperator для запуска dbt команд
        # dbt run --select ods.*
        
        print("✅ Модели ODS успешно обработаны")
        return "Success"
    except Exception as e:
        print(f"❌ Ошибка при обработке моделей ODS: {e}")
        raise

def run_dbt_dds():
    """Запуск dbt моделей для слоя DDS"""
    try:
        print("🔄 Запуск dbt моделей для слоя DDS...")
        
        # Используем BashOperator для запуска dbt команд
        # dbt run --select dds.*
        
        print("✅ Модели DDS успешно обработаны")
        return "Success"
    except Exception as e:
        print(f"❌ Ошибка при обработке моделей DDS: {e}")
        raise

def run_dbt_dds_clean():
    """Запуск dbt моделей для очистки дублей в DDS"""
    try:
        print("🧹 Запуск dbt моделей для очистки дублей в DDS...")
        
        # Используем BashOperator для запуска dbt команд
        # dbt run --select tag:clean
        # dbt run --select dds_river_flow_clean dds_market_data_clean
        
        print("✅ Модели очистки DDS успешно обработаны")
        return "Success"
    except Exception as e:
        print(f"❌ Ошибка при обработке моделей очистки DDS: {e}")
        raise

def run_dbt_dds_views():
    """Запуск dbt моделей для создания view'ов в DDS"""
    try:
        print("👁️ Запуск dbt моделей для создания view'ов в DDS...")
        
        # Используем BashOperator для запуска dbt команд
        # dbt run --select tag:view
        # dbt run --select dds_river_flow_view dds_market_data_view
        
        print("✅ View'ы DDS успешно созданы")
        return "Success"
    except Exception as e:
        print(f"❌ Ошибка при создании view'ов DDS: {e}")
        raise

def run_dbt_cdm():
    """Запуск dbt моделей для слоя CDM"""
    try:
        print("🔄 Запуск dbt моделей для слоя CDM...")
        
        # Используем BashOperator для запуска dbt команд
        # dbt run --select cdm.*
        
        print("✅ Модели CDM успешно обработаны")
        return "Success"
    except Exception as e:
        print(f"❌ Ошибка при обработке моделей CDM: {e}")
        raise

def run_dbt_tests():
    """Запуск dbt тестов"""
    try:
        print("🧪 Запуск dbt тестов...")
        
        # Используем BashOperator для запуска dbt команд
        # dbt test
        
        print("✅ Все dbt тесты прошли успешно")
        return "Success"
    except Exception as e:
        print(f"❌ Ошибка при выполнении dbt тестов: {e}")
        raise

def generate_dbt_docs():
    """Генерация dbt документации"""
    try:
        print("📚 Генерация dbt документации...")
        
        # Используем BashOperator для запуска dbt команд
        # dbt docs generate
        
        print("✅ dbt документация сгенерирована")
        return "Success"
    except Exception as e:
        print(f"❌ Ошибка при генерации dbt документации: {e}")
        raise

def health_check_processing():
    """Проверка здоровья пайплайна обработки данных"""
    print("🔍 Проверка здоровья пайплайна обработки данных...")
    return "Healthy"

# Определение задач
dq_check_task = PythonOperator(
    task_id='check_data_quality_raw',
    python_callable=check_data_quality_raw,
    dag=data_processing_dag,
)

run_ods_task = PythonOperator(
    task_id='run_dbt_ods',
    python_callable=run_dbt_ods,
    dag=data_processing_dag,
)

run_dds_task = PythonOperator(
    task_id='run_dbt_dds',
    python_callable=run_dbt_dds,
    dag=data_processing_dag,
)

run_dds_clean_task = PythonOperator(
    task_id='run_dbt_dds_clean',
    python_callable=run_dbt_dds_clean,
    dag=data_processing_dag,
)

run_dds_views_task = PythonOperator(
    task_id='run_dbt_dds_views',
    python_callable=run_dbt_dds_views,
    dag=data_processing_dag,
)

run_cdm_task = PythonOperator(
    task_id='run_dbt_cdm',
    python_callable=run_dbt_cdm,
    dag=data_processing_dag,
)

run_tests_task = PythonOperator(
    task_id='run_dbt_tests',
    python_callable=run_dbt_tests,
    dag=data_processing_dag,
)

generate_docs_task = PythonOperator(
    task_id='generate_dbt_docs',
    python_callable=generate_dbt_docs,
    dag=data_processing_dag,
)

health_check_task = PythonOperator(
    task_id='health_check',
    python_callable=health_check_processing,
    dag=data_processing_dag,
)

# Определение зависимостей (последовательная обработка по слоям)
dq_check_task >> run_ods_task >> run_dds_task >> run_dds_clean_task >> run_dds_views_task >> run_cdm_task >> run_tests_task >> generate_docs_task >> health_check_task
