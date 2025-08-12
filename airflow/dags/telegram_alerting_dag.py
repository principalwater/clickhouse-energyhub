"""
Продакшн DAG для мониторинга и алертинга в Apache Airflow.

Этот DAG отслеживает:
- Состояние DAG'ов (падения, ошибки)
- Системные метрики (CPU, RAM, Docker)
- Состояние ClickHouse кластера
- Отправляет уведомления в Telegram

Использует TelegramOperator 4.8.2+ с современным API
"""

import os
import json
import psutil
import docker
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.empty import EmptyOperator
from airflow.operators.trigger_dagrun import TriggerDagRunOperator
from airflow.models import DagRun, TaskInstance
from airflow.utils.session import provide_session
from sqlalchemy.orm import Session

# Попытка импорта официального TelegramOperator
try:
    from airflow.providers.telegram.operators.telegram import TelegramOperator
    TELEGRAM_AVAILABLE = True
    print("✅ TelegramOperator 4.8.2 доступен")
except ImportError:
    TELEGRAM_AVAILABLE = False
    print("❌ TelegramOperator недоступен. Установите: pip install apache-airflow-providers-telegram>=4.8.2")


def get_dag_status_report(**context):
    """
    Получает отчет о состоянии всех активных DAG'ов за последний день.
    """
    from airflow.models import DagRun, TaskInstance
    from airflow.utils.session import provide_session
    from sqlalchemy.orm import Session
    
    @provide_session
    def get_dag_runs(session: Session = None):
        # Получаем DAG'и за последние 24 часа
        yesterday = datetime.now() - timedelta(days=1)
        
        dag_runs = session.query(DagRun).filter(
            DagRun.start_date >= yesterday
        ).all()
        
        report = {
            'total_dags': len(dag_runs),
            'success': 0,
            'failed': 0,
            'running': 0,
            'failed_dags': [],
            'running_dags': []
        }
        
        for dag_run in dag_runs:
            if dag_run.state == 'success':
                report['success'] += 1
            elif dag_run.state == 'failed':
                report['failed'] += 1
                report['failed_dags'].append({
                    'dag_id': dag_run.dag_id,
                    'start_date': dag_run.start_date.isoformat(),
                    'end_date': dag_run.end_date.isoformat() if dag_run.end_date else None,
                    'duration': str(dag_run.end_date - dag_run.start_date) if dag_run.end_date else 'N/A'
                })
            elif dag_run.state == 'running':
                report['running'] += 1
                report['running_dags'].append({
                    'dag_id': dag_run.dag_id,
                    'start_date': dag_run.start_date.isoformat(),
                    'duration': str(datetime.now() - dag_run.start_date)
                })
        
        return report
    
    report = get_dag_runs()
    
    # Формируем сообщение для Telegram
    message = f"""📊 **Отчет по DAG'ам за последние 24 часа**

🔢 **Общая статистика:**
• Всего DAG'ов: {report['total_dags']}
• Успешно: {report['success']} ✅
• С ошибками: {report['failed']} ❌
• Выполняются: {report['running']} 🔄

"""
    
    if report['failed_dags']:
        message += "❌ **DAG'и с ошибками:**\n"
        for failed in report['failed_dags'][:5]:  # Показываем только первые 5
            message += f"• {failed['dag_id']} - {failed['start_date']}\n"
        if len(report['failed_dags']) > 5:
            message += f"• ... и еще {len(report['failed_dags']) - 5}\n"
    
    if report['running_dags']:
        message += "\n🔄 **Выполняющиеся DAG'и:**\n"
        for running in report['running_dags'][:3]:  # Показываем только первые 3
            message += f"• {running['dag_id']} - {running['duration']}\n"
        if len(report['running_dags']) > 3:
            message += f"• ... и еще {len(report['running_dags']) - 3}\n"
    
    # Сохраняем отчет в контексте для использования в других задачах
    context['task_instance'].xcom_push(key='dag_report', value=report)
    context['task_instance'].xcom_push(key='dag_message', value=message)
    
    return message


def get_system_metrics(**context):
    """
    Получает системные метрики (CPU, RAM, Docker).
    """
    try:
        # Системные метрики
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        
        # Docker метрики
        docker_metrics = {}
        try:
            client = docker.from_env()
            containers = client.containers.list()
            
            total_cpu = 0
            total_memory = 0
            running_containers = 0
            
            for container in containers:
                try:
                    stats = container.stats(stream=False)
                    # CPU usage (в процентах)
                    cpu_delta = stats['cpu_stats']['cpu_usage']['total_usage'] - stats['precpu_stats']['cpu_usage']['total_usage']
                    system_delta = stats['cpu_stats']['system_cpu_usage'] - stats['precpu_stats']['system_cpu_usage']
                    if system_delta > 0:
                        cpu_percent_container = (cpu_delta / system_delta) * 100
                        total_cpu += cpu_percent_container
                    
                    # Memory usage (в MB)
                    memory_usage = stats['memory_stats']['usage'] / (1024 * 1024)
                    total_memory += memory_usage
                    
                    running_containers += 1
                except:
                    continue
            
            docker_metrics = {
                'running_containers': running_containers,
                'avg_cpu_percent': total_cpu / running_containers if running_containers > 0 else 0,
                'total_memory_mb': total_memory,
                'avg_memory_mb': total_memory / running_containers if running_containers > 0 else 0
            }
        except Exception as e:
            docker_metrics = {'error': str(e)}
        
        metrics = {
            'timestamp': datetime.now().isoformat(),
            'system': {
                'cpu_percent': cpu_percent,
                'memory_percent': memory.percent,
                'memory_available_gb': round(memory.available / (1024**3), 2),
                'disk_percent': disk.percent,
                'disk_free_gb': round(disk.free / (1024**3), 2)
            },
            'docker': docker_metrics
        }
        
        # Формируем сообщение
        message = f"""🖥️ **Системные метрики**

💻 **CPU и память:**
• CPU: {cpu_percent}%
• RAM: {memory.percent}% ({memory.available_gb} GB свободно)
• Диск: {disk.percent}% ({disk.free_gb} GB свободно)

🐳 **Docker контейнеры:**
• Запущено: {docker_metrics.get('running_containers', 'N/A')}
• Средний CPU: {round(docker_metrics.get('avg_cpu_percent', 0), 1)}%
• Общая память: {round(docker_metrics.get('total_memory_mb', 0), 1)} MB

⏰ Время: {datetime.now().strftime('%H:%M:%S')}
"""
        
        # Сохраняем метрики в контексте
        context['task_instance'].xcom_push(key='system_metrics', value=metrics)
        context['task_instance'].xcom_push(key='system_message', value=message)
        
        return message
        
    except Exception as e:
        error_message = f"❌ Ошибка получения системных метрик: {str(e)}"
        context['task_instance'].xcom_push(key='system_error', value=str(e))
        return error_message


def get_clickhouse_metrics(**context):
    """
    Получает метрики ClickHouse кластера.
    """
    import requests
    from clickhouse_connect import get_client
    
    try:
        # Получаем переменные окружения
        ch_host = os.environ.get('CLICKHOUSE_HOST', 'clickhouse-01')
        ch_port = os.environ.get('CLICKHOUSE_PORT', '8123')
        ch_user = os.environ.get('CLICKHOUSE_USER', 'default')
        ch_password = os.environ.get('CLICKHOUSE_PASSWORD', '')
        
        metrics = {}
        
        # HTTP API метрики
        try:
            response = requests.get(
                f'http://{ch_host}:{ch_port}/metrics',
                auth=(ch_user, ch_password),
                timeout=10
            )
            if response.status_code == 200:
                metrics_text = response.text
                # Парсим основные метрики
                for line in metrics_text.split('\n'):
                    if line and not line.startswith('#'):
                        if 'ClickHouseProfileEvents_Query' in line:
                            metrics['total_queries'] = line.split()[-1]
                        elif 'ClickHouseProfileEvents_SelectQuery' in line:
                            metrics['select_queries'] = line.split()[-1]
                        elif 'ClickHouseProfileEvents_InsertQuery' in line:
                            metrics['insert_queries'] = line.split()[-1]
        except Exception as e:
            metrics['http_error'] = str(e)
        
        # SQL метрики через clickhouse-connect
        try:
            client = get_client(
                host=ch_host,
                port=int(ch_port),
                user=ch_user,
                password=ch_password
            )
            
            # Получаем информацию о таблицах
            tables_info = client.query("""
                SELECT 
                    database,
                    table,
                    total_rows,
                    total_bytes,
                    engine
                FROM system.tables 
                WHERE database NOT IN ('system', 'information_schema')
                ORDER BY total_bytes DESC
                LIMIT 10
            """)
            
            # Получаем информацию о запросах
            queries_info = client.query("""
                SELECT 
                    count() as active_queries,
                    max(query_duration_ms) as max_duration_ms
                FROM system.processes
                WHERE query NOT LIKE '%system%'
            """)
            
            # Получаем информацию о репликах
            replicas_info = client.query("""
                SELECT 
                    database,
                    table,
                    is_leader,
                    is_readonly,
                    absolute_delay
                FROM system.replicas
                WHERE database NOT IN ('system')
            """)
            
            client.close()
            
            metrics['tables'] = tables_info.result_rows
            metrics['queries'] = queries_info.result_rows[0] if queries_info.result_rows else [0, 0]
            metrics['replicas'] = replicas_info.result_rows
            
        except Exception as e:
            metrics['sql_error'] = str(e)
        
        # Формируем сообщение
        message = f"""🦘 **ClickHouse кластер - метрики**

📊 **Общая статистика:**
• Всего запросов: {metrics.get('total_queries', 'N/A')}
• SELECT запросов: {metrics.get('select_queries', 'N/A')}
• INSERT запросов: {metrics.get('insert_queries', 'N/A')}

🔍 **Активные запросы:**
• Выполняется: {metrics.get('queries', [0, 0])[0]}
• Макс. время: {metrics.get('queries', [0, 0])[1]} ms

📋 **Реплики:**
• Всего: {len(metrics.get('replicas', []))}
• Лидеры: {len([r for r in metrics.get('replicas', []) if r[2]])}
• Только чтение: {len([r for r in metrics.get('replicas', []) if r[3]])}

⏰ Время: {datetime.now().strftime('%H:%M:%S')}
"""
        
        # Сохраняем метрики в контексте
        context['task_instance'].xcom_push(key='clickhouse_metrics', value=metrics)
        context['task_instance'].xcom_push(key='clickhouse_message', value=message)
        
        return message
        
    except Exception as e:
        error_message = f"❌ Ошибка получения метрик ClickHouse: {str(e)}"
        context['task_instance'].xcom_push(key='clickhouse_error', value=str(e))
        return error_message


def check_dag_failures(**context):
    """
    Проверяет DAG'и на наличие ошибок и отправляет алерты.
    """
    from airflow.models import DagRun
    from airflow.utils.session import provide_session
    from sqlalchemy.orm import Session
    
    @provide_session
    def get_failed_dags(session: Session = None):
        # Проверяем DAG'и за последние 2 часа
        two_hours_ago = datetime.now() - timedelta(hours=2)
        
        failed_runs = session.query(DagRun).filter(
            DagRun.state == 'failed',
            DagRun.start_date >= two_hours_ago
        ).all()
        
        return failed_runs
    
    failed_dags = get_failed_dags()
    
    if failed_dags:
        # Есть ошибки - формируем алерт
        alert_message = f"""🚨 **АЛЕРТ: Обнаружены упавшие DAG'и!**

❌ **Количество ошибок:** {len(failed_dags)}

📋 **Список упавших DAG'ов:**
"""
        
        for dag_run in failed_dags[:5]:  # Показываем первые 5
            duration = "N/A"
            if dag_run.end_date and dag_run.start_date:
                duration = str(dag_run.end_date - dag_run.start_date)
            
            alert_message += f"""• **{dag_run.dag_id}**
  - Время: {dag_run.start_date.strftime('%H:%M:%S')}
  - Длительность: {duration}
  - ID запуска: {dag_run.run_id}

"""
        
        if len(failed_dags) > 5:
            alert_message += f"• ... и еще {len(failed_dags) - 5} DAG'ов с ошибками\n"
        
        alert_message += f"\n⏰ Время обнаружения: {datetime.now().strftime('%H:%M:%S')}"
        
        # Сохраняем алерт в контексте
        context['task_instance'].xcom_push(key='failure_alert', value=alert_message)
        context['task_instance'].xcom_push(key='has_failures', value=True)
        
        return alert_message
    else:
        # Ошибок нет
        success_message = "✅ Все DAG'и работают корректно"
        context['task_instance'].xcom_push(key='has_failures', value=False)
        return success_message


def send_telegram_notification(**context):
    """
    Отправляет уведомление в Telegram на основе собранных данных.
    """
    if not TELEGRAM_AVAILABLE:
        return "TelegramOperator недоступен"
    
    # Получаем данные из предыдущих задач
    ti = context['task_instance']
    
    dag_message = ti.xcom_pull(key='dag_message', task_ids='get_dag_status_report')
    system_message = ti.xcom_pull(key='system_message', task_ids='get_system_metrics')
    clickhouse_message = ti.xcom_pull(key='clickhouse_message', task_ids='get_clickhouse_metrics')
    has_failures = ti.xcom_pull(key='has_failures', task_ids='check_dag_failures')
    
    # Формируем итоговое сообщение
    if has_failures:
        # Есть ошибки - отправляем алерт
        failure_alert = ti.xcom_pull(key='failure_alert', task_ids='check_dag_failures')
        final_message = f"{failure_alert}\n\n{dag_message}\n\n{system_message}\n\n{clickhouse_message}"
    else:
        # Ошибок нет - отправляем обычный отчет
        final_message = f"{dag_message}\n\n{system_message}\n\n{clickhouse_message}"
    
    # Сохраняем финальное сообщение
    ti.xcom_push(key='final_message', value=final_message)
    
    return final_message


# Основной DAG для мониторинга
with DAG(
    'telegram_monitoring_prod',
    default_args={
        'owner': 'airflow',
        'depends_on_past': False,
        'start_date': datetime(2025, 8, 1),
        'email_on_failure': False,
        'email_on_retry': False,
        'retries': 2,
        'retry_delay': timedelta(minutes=5),
    },
    description='Продакшн мониторинг и алертинг через Telegram',
    schedule=timedelta(minutes=30),  # Каждые 30 минут
    catchup=False,
    tags=['monitoring', 'telegram', 'production', 'clickhouse'],
) as dag:

    start = EmptyOperator(task_id='start')
    
    # Получение отчета по DAG'ам
    get_dag_status = PythonOperator(
        task_id='get_dag_status_report',
        python_callable=get_dag_status_report,
    )
    
    # Получение системных метрик
    get_system_metrics_task = PythonOperator(
        task_id='get_system_metrics',
        python_callable=get_system_metrics,
    )
    
    # Получение метрик ClickHouse
    get_clickhouse_metrics_task = PythonOperator(
        task_id='get_clickhouse_metrics',
        python_callable=get_clickhouse_metrics,
    )
    
    # Проверка на ошибки DAG'ов
    check_failures = PythonOperator(
        task_id='check_dag_failures',
        python_callable=check_dag_failures,
    )
    
    # Подготовка уведомления
    prepare_notification = PythonOperator(
        task_id='prepare_notification',
        python_callable=send_telegram_notification,
    )
    
    end = EmptyOperator(task_id='end')
    
    # Telegram уведомления (только если доступны)
    if TELEGRAM_AVAILABLE:
        # Отправка уведомления
        telegram_notification = TelegramOperator(
            task_id='telegram_notification',
            telegram_conn_id='telegram_default',
            chat_id=os.environ.get('TELEGRAM_CHAT_ID', ''),
            text='{{ task_instance.xcom_pull(key="final_message", task_ids="prepare_notification") }}'
        )
        
        # Связываем задачи
        start >> [get_dag_status, get_system_metrics_task, get_clickhouse_metrics_task] >> check_failures >> prepare_notification >> telegram_notification >> end
    else:
        # Без Telegram - просто выполняем мониторинг
        start >> [get_dag_status, get_system_metrics_task, get_clickhouse_metrics_task] >> check_failures >> prepare_notification >> end


# DAG для ручного запуска отчета по команде
with DAG(
    'telegram_manual_report',
    default_args={
        'owner': 'airflow',
        'depends_on_past': False,
        'start_date': datetime(2025, 8, 1),
        'email_on_failure': False,
        'email_on_retry': False,
        'retries': 1,
        'retry_delay': timedelta(minutes=2),
    },
    description='Ручной запуск отчета по мониторингу',
    schedule=None,  # Только по триггеру
    catchup=False,
    tags=['monitoring', 'telegram', 'manual', 'report'],
) as dag:

    start = EmptyOperator(task_id='start')
    
    # Получение отчета по DAG'ам
    get_dag_status = PythonOperator(
        task_id='get_dag_status_report',
        python_callable=get_dag_status_report,
    )
    
    # Получение системных метрик
    get_system_metrics_task = PythonOperator(
        task_id='get_system_metrics',
        python_callable=get_system_metrics,
    )
    
    # Получение метрик ClickHouse
    get_clickhouse_metrics_task = PythonOperator(
        task_id='get_clickhouse_metrics',
        python_callable=get_clickhouse_metrics,
    )
    
    # Подготовка уведомления
    prepare_notification = PythonOperator(
        task_id='prepare_notification',
        python_callable=send_telegram_notification,
    )
    
    end = EmptyOperator(task_id='end')
    
    # Telegram уведомления (только если доступны)
    if TELEGRAM_AVAILABLE:
        # Отправка уведомления
        telegram_notification = TelegramOperator(
            task_id='telegram_notification',
            telegram_conn_id='telegram_default',
            chat_id=os.environ.get('TELEGRAM_CHAT_ID', ''),
            text='{{ task_instance.xcom_pull(key="final_message", task_ids="prepare_notification") }}'
        )
        
        # Связываем задачи
        start >> [get_dag_status, get_system_metrics_task, get_clickhouse_metrics_task] >> prepare_notification >> telegram_notification >> end
    else:
        # Без Telegram - просто выполняем мониторинг
        start >> [get_dag_status, get_system_metrics_task, get_clickhouse_metrics_task] >> prepare_notification >> end
