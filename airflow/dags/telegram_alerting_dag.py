"""
Продакшн DAG для мониторинга и алертинга в Apache Airflow.

Этот DAG отслеживает:
- Состояние DAG'ов (падения, ошибки)
- Системные метрики (CPU, RAM, Docker)
- Состояние ClickHouse кластера
- Отправляет уведомления в Telegram

Использует TelegramOperator 4.8.2+ с современным API

НАСТРОЙКА ПЕРЕМЕННЫХ ОКРУЖЕНИЯ:
Для работы с Telegram необходимо установить переменные окружения:
- TELEGRAM_BOT_TOKEN: токен вашего бота (получить у @BotFather)
- TELEGRAM_CHAT_ID: ID чата для отправки уведомлений

Пример:
export TELEGRAM_BOT_TOKEN="1234567890:ABCDEFghijklmnopqrstuvwxyz"
export TELEGRAM_CHAT_ID="-1001234567890"
"""

import os
import json
import psutil
import docker
from datetime import datetime, timedelta
import pytz
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.empty import EmptyOperator
from airflow.operators.trigger_dagrun import TriggerDagRunOperator
from airflow.api.client.local_client import Client
from airflow.configuration import conf

# Переменные окружения для Telegram
TELEGRAM_BOT_TOKEN = os.environ.get('TELEGRAM_BOT_TOKEN')
TELEGRAM_CHAT_ID = os.environ.get('TELEGRAM_CHAT_ID')

# Функция для получения московского времени
def get_moscow_time():
    """Возвращает текущее время в московском часовом поясе (UTC+3)"""
    moscow_tz = pytz.timezone('Europe/Moscow')
    utc_now = datetime.now(pytz.UTC)
    moscow_time = utc_now.astimezone(moscow_tz)
    return moscow_time.strftime('%H:%M:%S')

# Попытка импорта официального TelegramOperator
try:
    from airflow.providers.telegram.operators.telegram import TelegramOperator
    # Проверяем наличие переменных окружения
    if TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID:
        TELEGRAM_AVAILABLE = True
        print("✅ TelegramOperator 4.8.2 доступен, переменные окружения настроены")
    else:
        TELEGRAM_AVAILABLE = False
        print("❌ Telegram переменные окружения не настроены. Нужны: TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID")
except ImportError:
    TELEGRAM_AVAILABLE = False
    print("❌ TelegramOperator недоступен. Установите: pip install apache-airflow-providers-telegram>=4.8.2")


def get_dag_status_report(**context):
    """
    Получает отчет о состоянии всех активных DAG'ов за последний день.
    Совместимо с Airflow 3.0 - использует REST API вместо прямых ORM запросов.
    """
    import requests
    import json
    from airflow.configuration import conf
    
    try:
        # Получаем базовый URL Airflow - используем внутренний адрес контейнера
        webserver_base_url = conf.get('webserver', 'base_url', fallback='http://localhost:8080')
        api_url = f"{webserver_base_url}/api/v2"
        
        # Параметры для запроса DAG runs за последние 24 часа
        yesterday = datetime.now() - timedelta(days=1)
        start_date_gte = yesterday.isoformat()
        
        # Запрос к API для получения DAG runs
        dag_runs_response = requests.get(
            f"{api_url}/dags/~/dagRuns",
            params={
                'start_date_gte': start_date_gte,
                'limit': 1000
            },
            timeout=30
        )
        
        if dag_runs_response.status_code != 200:
            print(f"❌ Ошибка API: {dag_runs_response.status_code}")
            # Fallback к простой статистике
            return generate_fallback_report()
        
        dag_runs_data = dag_runs_response.json()
        dag_runs = dag_runs_data.get('dag_runs', [])
        
        report = {
            'total_dags': len(dag_runs),
            'success': 0,
            'failed': 0,
            'running': 0,
            'failed_dags': [],
            'running_dags': []
        }
        
        for dag_run in dag_runs:
            state = dag_run.get('state')
            if state == 'success':
                report['success'] += 1
            elif state == 'failed':
                report['failed'] += 1
                report['failed_dags'].append({
                    'dag_id': dag_run.get('dag_id'),
                    'start_date': dag_run.get('start_date'),
                    'end_date': dag_run.get('end_date'),
                    'duration': 'N/A'  # Упрощаем для API версии
                })
            elif state in ['running', 'queued']:
                report['running'] += 1
                report['running_dags'].append({
                    'dag_id': dag_run.get('dag_id'),
                    'start_date': dag_run.get('start_date'),
                    'duration': 'N/A'  # Упрощаем для API версии
                })
        
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
        
        if report['running_dags']:
            message += "\n🔄 **Выполняющиеся DAG'и:**\n"
            for running in report['running_dags'][:3]:  # Показываем только первые 3
                message += f"• {running['dag_id']} - запущен {running['start_date']}\n"
        
        message += f"\n⏰ Время отчета: {get_moscow_time()}"
        
        # Сохраняем отчет в контексте
        context['task_instance'].xcom_push(key='dag_report', value=message)
        context['task_instance'].xcom_push(key='dag_message', value=message)
        
        return message
        
    except Exception as e:
        print(f"❌ Ошибка получения статистики DAG'ов: {e}")
        error_report = generate_fallback_report()
        
        error_message = f"""📊 **Отчет по DAG'ам за последние 24 часа**

❌ **Ошибка получения данных**
Не удалось получить статистику из Airflow API.

⏰ Время отчета: {get_moscow_time()}
"""
        context['task_instance'].xcom_push(key='dag_report_error', value=str(e))
        context['task_instance'].xcom_push(key='dag_message', value=error_message)
        return error_message

def generate_fallback_report():
    """Генерирует простой отчет в случае ошибки API"""
    return {
        'total_dags': 0,
        'success': 0,
        'failed': 0,
        'running': 0,
        'failed_dags': [],
        'running_dags': []
    }


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
• RAM: {memory.percent}% ({round(memory.available / (1024**3), 2)} GB свободно)
• Диск: {disk.percent}% ({round(disk.free / (1024**3), 2)} GB свободно)

🐳 **Docker контейнеры:**
• Запущено: {docker_metrics.get('running_containers', 'N/A')}
• Средний CPU: {round(docker_metrics.get('avg_cpu_percent', 0), 1)}%
• Общая память: {round(docker_metrics.get('total_memory_mb', 0), 1)} MB

⏰ Время: {get_moscow_time()}
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
        
        # HTTP API проверка доступности
        try:
            print(f"🔍 Подключение к ClickHouse: {ch_host}:{ch_port}")
            # Простая проверка доступности через ping
            response = requests.get(
                f'http://{ch_host}:{ch_port}/ping',
                auth=(ch_user, ch_password),
                timeout=10
            )
            if response.status_code == 200:
                print("✅ ClickHouse HTTP API доступен")
                metrics['http_status'] = 'OK'
                
                # Попробуем получить простую статистику через SQL запрос к HTTP API
                sql_response = requests.get(
                    f'http://{ch_host}:{ch_port}/',
                    params={'query': 'SELECT 1'},
                    auth=(ch_user, ch_password),
                    timeout=10
                )
                if sql_response.status_code == 200:
                    metrics['sql_http_status'] = 'OK'
                else:
                    metrics['sql_http_status'] = f'HTTP {sql_response.status_code}'
            else:
                print(f"❌ ClickHouse HTTP API вернул статус: {response.status_code}")
                metrics['http_error'] = f"HTTP {response.status_code}"
        except Exception as e:
            print(f"❌ Ошибка подключения к ClickHouse HTTP API: {e}")
            metrics['http_error'] = str(e)
        
        # SQL метрики через clickhouse-connect
        try:
            print(f"🔍 SQL подключение к ClickHouse: {ch_user}@{ch_host}:{ch_port}")
            client = get_client(
                host=ch_host,
                port=int(ch_port),
                user=ch_user,
                password=ch_password
            )
            print("✅ ClickHouse SQL клиент подключен")
            
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
                    max(elapsed) as max_duration_sec
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
            print(f"❌ Ошибка SQL подключения к ClickHouse: {e}")
            metrics['sql_error'] = str(e)
        
        # Формируем сообщение
        message = f"""🦘 **ClickHouse кластер - метрики**

📊 **Общая статистика:**
• Всего запросов: {metrics.get('total_queries', 'N/A')}
• SELECT запросов: {metrics.get('select_queries', 'N/A')}
• INSERT запросов: {metrics.get('insert_queries', 'N/A')}

🔍 **Активные запросы:**
• Выполняется: {metrics.get('queries', [0, 0])[0]}
• Макс. время: {round(metrics.get('queries', [0, 0])[1], 2) if metrics.get('queries', [0, 0])[1] else 0} сек

📋 **Реплики:**
• Всего: {len(metrics.get('replicas', []))}
• Лидеры: {len([r for r in metrics.get('replicas', []) if r[2]])}
• Только чтение: {len([r for r in metrics.get('replicas', []) if r[3]])}"""

        # Добавляем информацию о статусе подключения
        status_info = []
        if 'http_status' in metrics:
            status_info.append(f"HTTP API: {metrics['http_status']}")
        elif 'http_error' in metrics:
            status_info.append(f"HTTP API: ❌ {metrics['http_error']}")
        
        if 'sql_error' not in metrics and metrics.get('queries') is not None:
            status_info.append("SQL: ✅ OK")
        elif 'sql_error' in metrics:
            status_info.append(f"SQL: ❌ {metrics['sql_error'][:100]}...")

        if status_info:
            message += "\n\n🔗 **Статус подключения:**"
            for info in status_info:
                message += f"\n• {info}"

        message += f"\n\n⏰ Время: {get_moscow_time()}"
        
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
    Совместимо с Airflow 3.0 - использует REST API.
    """
    import requests
    from airflow.configuration import conf
    
    try:
        # Получаем базовый URL Airflow - используем внутренний адрес контейнера
        webserver_base_url = conf.get('webserver', 'base_url', fallback='http://localhost:8080')
        api_url = f"{webserver_base_url}/api/v2"

        # Проверяем DAG'и за последние 2 часа
        two_hours_ago = datetime.now() - timedelta(hours=2)
        start_date_gte = two_hours_ago.isoformat()
        
        # Запрос к API для получения failed DAG runs
        dag_runs_response = requests.get(
            f"{api_url}/dags/~/dagRuns",
            params={
                'state': 'failed',
                'start_date_gte': start_date_gte,
                'limit': 100
            },
            timeout=30
        )
        
        if dag_runs_response.status_code != 200:
            print(f"❌ Ошибка API при проверке ошибок DAG'ов: {dag_runs_response.status_code}")
            failed_dags = []
        else:
            dag_runs_data = dag_runs_response.json()
            failed_dags = dag_runs_data.get('dag_runs', [])
        
    except Exception as e:
        print(f"❌ Ошибка получения списка упавших DAG'ов: {e}")
        failed_dags = []
    
    if failed_dags:
        # Есть ошибки - формируем алерт
        alert_message = f"""🚨 **АЛЕРТ: Обнаружены упавшие DAG'и!**

❌ **Количество ошибок:** {len(failed_dags)}

📋 **Список упавших DAG'ов:**
"""
        
        for dag_run in failed_dags[:5]:  # Показываем первые 5
            dag_id = dag_run.get('dag_id', 'Unknown')
            run_id = dag_run.get('dag_run_id', 'Unknown')
            start_date = dag_run.get('start_date', '')
            
            # Форматируем время start_date
            if start_date:
                try:
                    start_dt = datetime.fromisoformat(start_date.replace('Z', '+00:00'))
                    formatted_time = start_dt.strftime('%H:%M:%S')
                except:
                    formatted_time = start_date
            else:
                formatted_time = 'Unknown'
            
            alert_message += f"""• **{dag_id}**
  - Время: {formatted_time}
  - Длительность: N/A
  - ID запуска: {run_id}

"""
        
        if len(failed_dags) > 5:
            alert_message += f"• ... и еще {len(failed_dags) - 5} DAG'ов с ошибками\n"
        
        alert_message += f"\n⏰ Время обнаружения: {get_moscow_time()}"
        
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
            token=TELEGRAM_BOT_TOKEN,  # Используем переменную окружения
            chat_id=TELEGRAM_CHAT_ID,
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
            token=TELEGRAM_BOT_TOKEN,  # Используем переменную окружения
            chat_id=TELEGRAM_CHAT_ID,
            text='{{ task_instance.xcom_pull(key="final_message", task_ids="prepare_notification") }}'
        )
        
        # Связываем задачи
        start >> [get_dag_status, get_system_metrics_task, get_clickhouse_metrics_task] >> prepare_notification >> telegram_notification >> end
    else:
        # Без Telegram - просто выполняем мониторинг
        start >> [get_dag_status, get_system_metrics_task, get_clickhouse_metrics_task] >> prepare_notification >> end
