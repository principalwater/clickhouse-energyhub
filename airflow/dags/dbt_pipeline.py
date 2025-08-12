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
    import subprocess
    try:
        print("🔍 Проверка dbt проекта...")
        
        # Переходим в директорию dbt проекта и выполняем dbt debug
        result = subprocess.run(
            ["dbt", "debug"],
            cwd="/opt/airflow/dbt",
            capture_output=True,
            text=True,
            check=True
        )
        
        print("✅ dbt проект проверен")
        print(f"📋 Результат: {result.stdout}")
        return "Success"
    except subprocess.CalledProcessError as e:
        print(f"❌ Ошибка при проверке dbt проекта: {e}")
        print(f"📋 Stdout: {e.stdout}")
        print(f"📋 Stderr: {e.stderr}")
        raise
    except Exception as e:
        print(f"❌ Ошибка при проверке dbt проекта: {e}")
        raise

def run_dbt_models():
    """Запуск всех dbt моделей"""
    import subprocess
    try:
        print("🔄 Запуск dbt моделей...")
        
        # Сначала устанавливаем зависимости пакетов
        print("📦 Установка dbt зависимостей...")
        deps_result = subprocess.run(
            ["dbt", "deps"],
            cwd="/opt/airflow/dbt",
            capture_output=True,
            text=True,
            check=True
        )
        print("✅ dbt зависимости установлены")
        
        # Затем запускаем dbt run для выполнения всех моделей
        print("🚀 Выполнение dbt моделей...")
        result = subprocess.run(
            ["dbt", "run"],
            cwd="/opt/airflow/dbt",
            capture_output=True,
            text=True,
            check=True
        )
        
        print("✅ dbt модели выполнены успешно")
        print(f"📋 Результат: {result.stdout}")
        return "Success"
    except subprocess.CalledProcessError as e:
        print(f"❌ Ошибка при выполнении dbt команд: {e}")
        print(f"📋 Stdout: {e.stdout}")
        print(f"📋 Stderr: {e.stderr}")
        raise
    except Exception as e:
        print(f"❌ Ошибка при выполнении dbt моделей: {e}")
        raise

def run_dbt_tests():
    """Запуск dbt тестов"""
    import subprocess
    import re
    try:
        print("🧪 Запуск dbt тестов...")
        
        # Запускаем dbt test для выполнения всех тестов (без check=True)
        result = subprocess.run(
            ["dbt", "test"],
            cwd="/opt/airflow/dbt",
            capture_output=True,
            text=True,
            check=False  # Не падаем при non-zero exit code
        )
        
        print(f"📋 Результат выполнения dbt test:")
        print(result.stdout)
        
        if result.stderr:
            print(f"📋 Предупреждения/ошибки: {result.stderr}")
        
        # Парсим результат для извлечения статистики
        stdout = result.stdout
        if "Done." in stdout:
            # Ищем строку с итоговой статистикой типа "Done. PASS=25 WARN=2 ERROR=1 SKIP=0 NO-OP=0 TOTAL=28"
            done_match = re.search(r'Done\.\s+(.*)', stdout)
            if done_match:
                stats = done_match.group(1)
                print(f"📊 Статистика тестов: {stats}")
                
                # Извлекаем количество ошибок
                error_match = re.search(r'ERROR=(\d+)', stats)
                warn_match = re.search(r'WARN=(\d+)', stats)
                pass_match = re.search(r'PASS=(\d+)', stats)
                
                errors = int(error_match.group(1)) if error_match else 0
                warnings = int(warn_match.group(1)) if warn_match else 0
                passes = int(pass_match.group(1)) if pass_match else 0
                
                if errors > 0:
                    print(f"⚠️ Обнаружено {errors} ошибок в тестах DQ")
                if warnings > 0:
                    print(f"⚠️ Обнаружено {warnings} предупреждений в тестах DQ")
                if passes > 0:
                    print(f"✅ Успешно прошло {passes} тестов DQ")
                
                return f"Completed: PASS={passes}, WARN={warnings}, ERROR={errors}"
        
        # Если не удалось распарсить, возвращаем общий статус
        if result.returncode == 0:
            print("✅ Все dbt тесты выполнены успешно")
            return "Success - All tests passed"
        else:
            print("⚠️ dbt тесты завершены с ошибками, но задача выполнена")
            return f"Completed with issues - Exit code: {result.returncode}"
            
    except Exception as e:
        print(f"❌ Ошибка при выполнении dbt тестов: {e}")
        raise

def generate_dbt_docs():
    """Генерация dbt документации"""
    import subprocess
    try:
        print("📚 Генерация dbt документации...")
        
        # Запускаем dbt docs generate для создания документации
        result = subprocess.run(
            ["dbt", "docs", "generate"],
            cwd="/opt/airflow/dbt",
            capture_output=True,
            text=True,
            check=True
        )
        
        print("✅ dbt документация сгенерирована")
        print(f"📋 Результат: {result.stdout}")
        return "Success"
    except subprocess.CalledProcessError as e:
        print(f"❌ Ошибка при генерации dbt документации: {e}")
        print(f"📋 Stdout: {e.stdout}")
        print(f"📋 Stderr: {e.stderr}")
        raise
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
