"""
ClickHouse Backup Pipeline DAG

Этот DAG выполняет операции бэкапа и восстановления ClickHouse.

Режимы работы:
1. Обычный режим (по умолчанию): создание бэкапа, проверка, очистка старых бэкапов
2. Режим восстановления: восстановление из указанного бэкапа

Примеры использования:

1. Обычный запуск (создание бэкапа):
   - Запускается по расписанию каждый день в 3:00
   - Выполняются шаги: list_backups -> create_backup -> verify_backup -> cleanup_old_backups -> health_check

2. Запуск в режиме восстановления через JSON триггер:
   {
     "restore_mode": true,
     "backup_name": "backup_2025_01_15_03_00_00"
   }

3. Запуск в режиме восстановления через Airflow UI:
   - В разделе "Trigger DAG" указать JSON конфигурацию:
   {
     "restore_mode": true,
     "backup_name": "backup_2025_01_15_03_00_00"
   }

Параметры:
- restore_mode (bool): если true, запускается режим восстановления
- backup_name (str): имя бэкапа для восстановления (опционально, по умолчанию используется последний бэкап)
- force_restore (bool): принудительное восстановление без проверки изменений (по умолчанию false)
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator, BranchPythonOperator
from airflow.operators.bash import BashOperator
from airflow.models import Variable
from airflow.operators.trigger_dagrun import TriggerDagRunOperator
from airflow.utils.trigger_rule import TriggerRule
from airflow.operators.empty import EmptyOperator
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

# Создание DAG для бэкапа и восстановления ClickHouse
backup_dag = DAG(
    'clickhouse_backup_pipeline',
    default_args=default_args,
    description='Бэкап и восстановление ClickHouse через clickhouse-backup',
    schedule='0 3 * * *',  # Каждый день в 3:00
    catchup=False,
    tags=['clickhouse', 'backup', 'restore'],
)

def create_backup(**context):
    """Создание бэкапа ClickHouse"""
    try:
        # Импортируем менеджер бэкапов
        from clickhouse_backup_manager import ClickHouseBackupManager
        
        manager = ClickHouseBackupManager()
        backup_name = manager.create_backup()
        
        # Сохраняем имя бэкапа в XCom для возможного использования в других задачах
        context['task_instance'].xcom_push(key='backup_name', value=backup_name)
        
        return backup_name
            
    except Exception as e:
        print(f"❌ Ошибка при создании бэкапа: {e}")
        raise

def list_backups(**context):
    """Список доступных бэкапов"""
    try:
        from clickhouse_backup_manager import ClickHouseBackupManager
        
        manager = ClickHouseBackupManager()
        backups_list = manager.list_backups()
        
        # Сохраняем список в XCom
        context['task_instance'].xcom_push(key='backups_list', value=backups_list)
        
        return backups_list
            
    except Exception as e:
        print(f"❌ Ошибка при получении списка бэкапов: {e}")
        raise

def restore_from_backup(**context):
    """Восстановление из бэкапа"""
    try:
        from clickhouse_backup_manager import ClickHouseBackupManager
        
        manager = ClickHouseBackupManager()
        
        # Получаем параметры из конфигурации
        backup_name = context['dag_run'].conf.get('backup_name', None)
        force_restore = context['dag_run'].conf.get('force_restore', False)
        
        if backup_name:
            print(f"🔄 Восстановление из указанного бэкапа: {backup_name}")
        else:
            print("🔄 Восстановление из последнего доступного бэкапа")
        
        if force_restore:
            print("🔧 Принудительное восстановление активировано")
        
        result = manager.restore_backup(backup_name, force=force_restore)
        print(f"✅ Восстановление завершено: {result}")
        return result
            
    except Exception as e:
        print(f"❌ Ошибка при восстановлении: {e}")
        raise

def verify_backup(**context):
    """Проверка целостности бэкапа"""
    try:
        from clickhouse_backup_manager import ClickHouseBackupManager
        
        manager = ClickHouseBackupManager()
        
        # Получаем имя бэкапа из предыдущей задачи
        backup_name = context['task_instance'].xcom_pull(task_ids='create_backup', key='backup_name')
        
        if not backup_name:
            print("⚠️ Имя бэкапа не найдено, пропускаем проверку")
            return "Skipped"
        
        success = manager.verify_backup(backup_name)
        if success:
            return "Verified"
        else:
            raise Exception(f"Бэкап {backup_name} не найден")
            
    except Exception as e:
        print(f"❌ Ошибка при проверке бэкапа: {e}")
        raise

def cleanup_old_backups(**context):
    """Очистка старых бэкапов (оставляем последние 7)"""
    try:
        from clickhouse_backup_manager import ClickHouseBackupManager
        
        manager = ClickHouseBackupManager()
        result = manager.cleanup_old_backups(7)
        return result
            
    except Exception as e:
        print(f"❌ Ошибка при очистке бэкапов: {e}")
        raise

def health_check_backup():
    """Проверка здоровья системы бэкапов"""
    print("🔍 Проверка здоровья системы бэкапов...")
    
    try:
        from clickhouse_backup_manager import ClickHouseBackupManager
        
        manager = ClickHouseBackupManager()
        success = manager.test_clickhouse_connection()
        
        if success:
            return "Healthy"
        else:
            return "Unhealthy"
        
    except Exception as e:
        print(f"❌ Ошибка при проверке здоровья: {e}")
        return "Unhealthy"

def choose_mode(**context):
    """Выбирает режим работы: бэкап или восстановление"""
    restore_mode = context['dag_run'].conf.get('restore_mode', False)
    
    if restore_mode:
        print("🔄 Режим восстановления активирован")
        return 'restore_backup'
    else:
        print("💾 Режим создания бэкапа активирован")
        return 'create_backup'

# Определение задач
start_task = EmptyOperator(
    task_id='start',
    dag=backup_dag,
)

list_backups_task = PythonOperator(
    task_id='list_backups',
    python_callable=list_backups,
    dag=backup_dag,
)

mode_choice = BranchPythonOperator(
    task_id='choose_mode',
    python_callable=choose_mode,
    dag=backup_dag,
)

create_backup_task = PythonOperator(
    task_id='create_backup',
    python_callable=create_backup,
    dag=backup_dag,
    trigger_rule=TriggerRule.NONE_FAILED,
)

verify_backup_task = PythonOperator(
    task_id='verify_backup',
    python_callable=verify_backup,
    dag=backup_dag,
    trigger_rule=TriggerRule.NONE_FAILED,
)

restore_backup_task = PythonOperator(
    task_id='restore_backup',
    python_callable=restore_from_backup,
    dag=backup_dag,
    trigger_rule=TriggerRule.NONE_FAILED,
)

cleanup_backups_task = PythonOperator(
    task_id='cleanup_old_backups',
    python_callable=cleanup_old_backups,
    dag=backup_dag,
    trigger_rule=TriggerRule.NONE_FAILED,
)

health_check_task = PythonOperator(
    task_id='health_check',
    python_callable=health_check_backup,
    dag=backup_dag,
    trigger_rule=TriggerRule.NONE_FAILED,
)

end_task = EmptyOperator(
    task_id='end',
    dag=backup_dag,
    trigger_rule=TriggerRule.NONE_FAILED,
)

# Определение зависимостей
start_task >> list_backups_task >> mode_choice

# Ветка для создания бэкапа
mode_choice >> create_backup_task >> verify_backup_task >> cleanup_backups_task >> health_check_task >> end_task

# Ветка для восстановления
mode_choice >> restore_backup_task >> health_check_task >> end_task
