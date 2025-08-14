"""
Продакшн DAG для мониторинга и алертинга в Apache Airflow.

Этот DAG отслеживает:
- Состояние DAG Run (падения, ошибки)
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
import logging
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
    Получает отчет о состоянии всех активных DAG.
    Использует прямое подключение к базе данных через SQLAlchemy.
    """
    from datetime import datetime, timedelta
    from sqlalchemy import create_engine, text
    from airflow.models import DagBag
    import os
    
    try:
        print("🔍 Получение статистики DAG из базы данных")
        
        # Получаем список всех DAG через DagBag
        try:
            dagbag = DagBag()
            total_dags = len(dagbag.dags)
            print(f"✅ Найдено DAG: {total_dags}")
        except Exception as e:
            print(f"❌ Ошибка получения списка DAG: {e}")
            total_dags = 0
        
        # Инициализируем счетчики
        total_success = 0
        total_failed = 0
        total_running = 0
        total_queued = 0
        total_dag_runs = 0  # Общее количество DAG Run
        failed_dags = []
        running_dags = []
        queued_dags = []
        
        # Получаем параметры подключения к базе данных
        try:
            # Сначала пробуем получить из Airflow connections
            from airflow.hooks.base import BaseHook
            conn = BaseHook.get_connection('airflow_db')
            connection_string = conn.get_uri()
            print(f"🔗 Подключение к БД через Airflow connection: {conn.host}:{conn.port}/{conn.schema}")
        except:
            # Fallback к прямому подключению к PostgreSQL контейнеру
            # Используем стандартные параметры из Terraform
            db_host = 'postgres'  # Имя контейнера PostgreSQL
            db_port = '5432'
            db_user = 'airflow'
            db_password = 'airflow'  # Будет заменено на реальный пароль из переменных
            db_name = 'airflow'
            
            # Пытаемся получить пароль из переменных окружения
            airflow_pg_password = os.environ.get('AIRFLOW_POSTGRES_PASSWORD')
            if airflow_pg_password:
                db_password = airflow_pg_password
            else:
                # Fallback к паролю из terraform.tfvars
                db_password = 'AirflowPassword123!'
            
            connection_string = f"postgresql://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}"
            
            # Маскируем пароль для логирования
            masked_connection = connection_string.replace(db_password, '***')
            print(f"🔗 Подключение к БД напрямую: {masked_connection}")
            print(f"🔍 Параметры подключения: host={db_host}, port={db_port}, user={db_user}, db={db_name}")
        
        # Создаем подключение к базе данных
        engine = create_engine(connection_string)
        
        # Тестируем подключение
        try:
            with engine.connect() as test_conn:
                test_conn.execute(text("SELECT 1"))
            print("✅ Подключение к БД успешно установлено")
        except Exception as e:
            print(f"❌ Ошибка подключения к БД: {e}")
            raise
        
        # Получаем статистику за последние 24 часа
        yesterday = datetime.now() - timedelta(days=1)
        
        with engine.connect() as conn:
            # Запрос для получения статистики по статусам
            query = text("""
                SELECT 
                    dag_id,
                    state,
                    COUNT(*) as count
                FROM dag_run 
                WHERE start_date >= :start_date
                GROUP BY dag_id, state
                ORDER BY dag_id, state
            """)
            
            result = conn.execute(query, {'start_date': yesterday})
            
            # Группируем данные по DAG
            dag_stats = {}
            for row in result:
                dag_id = row.dag_id
                state = row.state
                count = row.count
                
                if dag_id not in dag_stats:
                    dag_stats[dag_id] = {}
                
                dag_stats[dag_id][state] = count
                
                # Обновляем общую статистику
                total_dag_runs += count  # Добавляем к общему количеству DAG Run
                if state == 'success':
                    total_success += count
                elif state == 'failed':
                    total_failed += count
                elif state == 'running':
                    total_running += count
                elif state == 'queued':
                    total_queued += count
            
            # Формируем списки DAG по статусам
            for dag_id, states in dag_stats.items():
                if 'failed' in states and states['failed'] > 0:
                    failed_dags.append({
                        'dag_id': dag_id,
                        'count': states['failed']
                    })
                
                if 'running' in states and states['running'] > 0:
                    running_dags.append({
                        'dag_id': dag_id,
                        'count': states['running']
                    })
                
                if 'queued' in states and states['queued'] > 0:
                    queued_dags.append({
                        'dag_id': dag_id,
                        'count': states['queued']
                    })
            
            print(f"📊 Статистика из БД: Success={total_success}, Failed={total_failed}, Running={total_running}, Queued={total_queued}")
            
            # Получаем текущее время в московском часовом поясе
            current_time = get_moscow_time()
            
            # Формируем отчет
            dag_status_report = f"""
📊 **Статистика DAG за последние 24 часа**
⏰ Время: {current_time}

📈 **Общая статистика:**
• Всего DAG: {total_dags}
• Всего DAG Run: {total_dag_runs}
• Успешных: {total_success} ✅
• Упавших: {total_failed} ❌
• Выполняющихся: {total_running} 🔄
• В очереди: {total_queued} ⏳

"""
            
            # Добавляем информацию об упавших DAG
            if failed_dags:
                dag_status_report += f"❌ **Упавшие DAG ({len(failed_dags)}):**\n"
                for dag_info in failed_dags[:5]:  # Показываем первые 5
                    dag_status_report += f"• `{dag_info['dag_id']}` ({dag_info['count']} раз)\n"
                if len(failed_dags) > 5:
                    dag_status_report += f"• ... и еще {len(failed_dags) - 5}\n"
                dag_status_report += "\n"
            
            # Добавляем информацию о выполняющихся DAG
            if running_dags:
                dag_status_report += f"🔄 **Выполняющиеся DAG ({len(running_dags)}):**\n"
                for dag_info in running_dags[:5]:  # Показываем первые 5
                    dag_status_report += f"• `{dag_info['dag_id']}` ({dag_info['count']} раз)\n"
                if len(running_dags) > 5:
                    dag_status_report += f"• ... и еще {len(running_dags) - 5}\n"
                dag_status_report += "\n"
            
            # Добавляем информацию о DAG в очереди
            if queued_dags:
                dag_status_report += f"⏳ **DAG в очереди ({len(queued_dags)}):**\n"
                for dag_info in queued_dags[:3]:  # Показываем первые 3
                    dag_status_report += f"• `{dag_info['dag_id']}` ({dag_info['count']} раз)\n"
                if len(queued_dags) > 3:
                    dag_status_report += f"• ... и еще {len(queued_dags) - 3}\n"
                dag_status_report += "\n"
            
            # Сохраняем данные в контексте
            context['task_instance'].xcom_push(key='dag_message', value=dag_status_report)
            context['task_instance'].xcom_push(key='dag_stats', value={
                'total_dags': total_dags,
                'total_dag_runs': total_dag_runs,
                'success_count': total_success,
                'failed_count': total_failed,
                'running_count': total_running,
                'queued_count': total_queued,
                'failed_dags': failed_dags,
                'running_dags': running_dags,
                'queued_dags': queued_dags
            })
            
            print("✅ Отчет о состоянии DAG сформирован")
            return dag_status_report
            
    except Exception as e:
        print(f"❌ Ошибка получения статистики из БД: {e}")
        # Fallback к простой статистике
        total_success = 0
        total_failed = 0
        total_running = 0
        total_queued = 0
        total_dag_runs = 0
        
        # Получаем текущее время в московском часовом поясе
        current_time = get_moscow_time()
        
        # Формируем отчет
        dag_status_report = f"""
📊 **Статистика DAG за последние 24 часа**
⏰ Время: {current_time}

📈 **Общая статистика:**
• Всего DAG: {total_dags}
• Всего DAG Run: {total_dag_runs}
• Успешных: {total_success} ✅
• Упавших: {total_failed} ❌
• Выполняющихся: {total_running} 🔄
• В очереди: {total_queued} ⏳

"""
        
        # Добавляем информацию об упавших DAG
        if failed_dags:
            dag_status_report += f"❌ **Упавшие DAG ({len(failed_dags)}):**\n"
            for dag_info in failed_dags[:5]:  # Показываем первые 5
                dag_status_report += f"• `{dag_info['dag_id']}` ({dag_info['count']} раз)\n"
            if len(failed_dags) > 5:
                dag_status_report += f"• ... и еще {len(failed_dags) - 5}\n"
            dag_status_report += "\n"
        
        # Добавляем информацию о выполняющихся DAG
        if running_dags:
            dag_status_report += f"🔄 **Выполняющиеся DAG ({len(running_dags)}):**\n"
            for dag_info in running_dags[:5]:  # Показываем первые 5
                dag_status_report += f"• `{dag_info['dag_id']}` ({dag_info['count']} раз)\n"
            if len(running_dags) > 5:
                dag_status_report += f"• ... и еще {len(running_dags) - 5}\n"
            dag_status_report += "\n"
        
        # Добавляем информацию о DAG в очереди
        if queued_dags:
            dag_status_report += f"⏳ **DAG в очереди ({len(queued_dags)}):**\n"
            for dag_info in queued_dags[:3]:  # Показываем первые 3
                dag_status_report += f"• `{dag_info['dag_id']}` ({dag_info['count']} раз)\n"
            if len(queued_dags) > 3:
                dag_status_report += f"• ... и еще {len(queued_dags) - 3}\n"
            dag_status_report += "\n"
        
        # Сохраняем данные в контексте
        context['task_instance'].xcom_push(key='dag_message', value=dag_status_report)
        context['task_instance'].xcom_push(key='dag_stats', value={
            'total_dags': total_dags,
            'success_count': total_success,
            'failed_count': total_failed,
            'running_count': total_running,
            'queued_count': total_queued,
            'failed_dags': failed_dags,
            'running_dags': running_dags,
            'queued_dags': queued_dags
        })
        
        print("✅ Отчет о состоянии DAG сформирован")
        return dag_status_report
        
    except Exception as e:
        error_message = f"❌ Ошибка получения статистики DAG: {str(e)}"
        print(error_message)
        context['task_instance'].xcom_push(key='dag_message', value=error_message)
        return error_message

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
• Всего таблиц: {len(metrics.get('tables', []))}
• Активные запросы: {metrics.get('queries', [0, 0])[0] if metrics.get('queries') else 0}
• Макс. время запроса: {round(metrics.get('queries', [0, 0])[1], 2) if metrics.get('queries') and metrics.get('queries')[1] else 0} сек

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
    Проверяет DAG'и на наличие ошибок на основе данных из get_dag_status_report.
    Использует данные, уже полученные из базы данных.
    """
    try:
        print("🔍 Проверка DAG на наличие ошибок")
        
        # Получаем данные из предыдущей задачи
        ti = context['task_instance']
        dag_stats = ti.xcom_pull(key='dag_stats', task_ids='get_dag_status_report')
        
        if not dag_stats:
            print("⚠️ Данные о DAG'ах не найдены")
            context['task_instance'].xcom_push(key='has_failures', value=False)
            return "Данные о DAG'ах не найдены"
        
        failed_count = dag_stats.get('failed_count', 0)
        failed_dags = dag_stats.get('failed_dags', [])
        
        print(f"📊 Найдено упавших DAG: {failed_count}")
        
        # Проверяем наличие ошибок
        has_failures = failed_count > 0
        
        # Сохраняем результат
        context['task_instance'].xcom_push(key='has_failures', value=has_failures)
        
        if has_failures:
            # Формируем алерт
            alert_message = f"""
🚨 **АЛЕРТ: Обнаружены упавшие DAG**

❌ **Количество упавших DAG:** {failed_count}

📋 **Список упавших DAG:**
"""
            
            for dag_info in failed_dags[:10]:  # Показываем первые 10
                alert_message += f"• `{dag_info['dag_id']}` ({dag_info['count']} раз)\n"
            
            if len(failed_dags) > 10:
                alert_message += f"• ... и еще {len(failed_dags) - 10}\n"
            
            alert_message += f"""
⏰ Время: {get_moscow_time()}

🔧 **Рекомендации:**
• Проверьте логи упавших DAG в Airflow UI
• Убедитесь, что все зависимости доступны
• Проверьте настройки подключений к базам данных
"""
            
            context['task_instance'].xcom_push(key='failure_alert', value=alert_message)
            print("🚨 Алерт сформирован")
            return alert_message
        else:
            # Все в порядке
            success_message = f"✅ Все DAG работают нормально. Время: {get_moscow_time()}"
            context['task_instance'].xcom_push(key='failure_alert', value=success_message)
            print("✅ Ошибок не обнаружено")
            return success_message
            
    except Exception as e:
        error_message = f"❌ Ошибка проверки DAG: {str(e)}"
        print(error_message)
        context['task_instance'].xcom_push(key='has_failures', value=False)
        context['task_instance'].xcom_push(key='failure_alert', value=error_message)
        return error_message


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
    description='Продакшн мониторинг и алертинг через Telegram (каждые 30 минут)',
    schedule='*/30 * * * *',  # Каждые 30 минут (в 00 и 30 минут каждого часа)
    catchup=False,
    tags=['monitoring', 'telegram', 'production', 'clickhouse'],
) as dag:

    start = EmptyOperator(task_id='start')
    
    # Получение отчета по DAG
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
    
    # Проверка на ошибки DAG
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
    
    # Получение отчета по DAG
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
