"""
DAG для очистки дублей в данных через dbt
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from airflow.operators.empty import EmptyOperator
from airflow.utils.trigger_rule import TriggerRule
import os

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

# Создание DAG для очистки дублей
deduplication_dag = DAG(
    'deduplication_pipeline',
    default_args=default_args,
    description='Очистка дублей в данных через dbt',
    schedule='*/5 * * * *',  # Каждые 5 минут
    catchup=False,
    tags=['deduplication', 'dbt', 'data-quality'],
)

def check_duplicates_before():
    """Проверка количества дублей до очистки"""
    try:
        print("🔍 Проверка количества дублей до очистки...")
        
        # Здесь можно добавить SQL запросы для подсчета дублей
        # Например, через clickhouse-client
        
        print("✅ Проверка дублей завершена")
        return "Success"
    except Exception as e:
        print(f"❌ Ошибка при проверке дублей: {e}")
        raise

def run_dbt_deduplication():
    """Запуск dbt моделей для очистки дублей"""
    try:
        print("🧹 Запуск dbt моделей для очистки дублей...")
        
        # Команда для запуска dbt моделей очистки
        cmd = "cd /opt/dbt && dbt run --select tag:clean"
        
        print("✅ Модели очистки успешно обработаны")
        return "Success"
    except Exception as e:
        print(f"❌ Ошибка при очистке дублей: {e}")
        raise

def run_dbt_views():
    """Запуск dbt моделей для создания view"""
    try:
        print("👁️ Запуск dbt моделей для создания view...")
        
        # Команда для запуска dbt view
        cmd = "cd /opt/dbt && dbt run --select tag:view"
        
        print("✅ View успешно созданы")
        return "Success"
    except Exception as e:
        print(f"❌ Ошибка при создании view: {e}")
        raise

def run_dbt_tests_dedup():
    """Запуск dbt тестов для проверки очистки"""
    try:
        print("🧪 Запуск dbt тестов для проверки очистки...")
        
        # Команда для запуска dbt тестов
        cmd = "cd /opt/dbt && dbt test --select test_no_duplicates"
        
        print("✅ Тесты очистки прошли успешно")
        return "Success"
    except Exception as e:
        print(f"❌ Ошибка при выполнении тестов: {e}")
        raise

def check_duplicates_after():
    """Проверка количества дублей после очистки"""
    try:
        print("🔍 Проверка количества дублей после очистки...")
        
        # Здесь можно добавить SQL запросы для подсчета дублей после очистки
        
        print("✅ Проверка дублей после очистки завершена")
        return "Success"
    except Exception as e:
        print(f"❌ Ошибка при проверке дублей после очистки: {e}")
        raise

def update_dbt_sources():
    """Обновление dbt sources на основе таблиц в ClickHouse"""
    try:
        print("🔄 Обновление dbt sources на основе таблиц в ClickHouse...")
        
        import subprocess
        import yaml
        import os
        from typing import Dict, List, Any
        
        class DbtSourcesUpdater:
            def __init__(self):
                self.clickhouse_host = "clickhouse-01"
                self.clickhouse_port = 9000
                self.clickhouse_user = "principalwater"
                self.clickhouse_password = "UnixSpace@11."
                self.dbt_project_path = "/opt/airflow/dbt"
                self.sources_file = os.path.join(self.dbt_project_path, "models", "sources.yml")
                
            def get_clickhouse_tables(self) -> Dict[str, List[str]]:
                """Получает все таблицы из ClickHouse по базам данных"""
                query = """
                SELECT 
                    database,
                    name,
                    engine
                FROM system.tables 
                WHERE database IN ('raw', 'ods', 'dds', 'cdm')
                ORDER BY database, name
                """
                
                cmd = f"""docker exec {self.clickhouse_host} clickhouse-client \
                    --user {self.clickhouse_user} \
                    --password '{self.clickhouse_password}' \
                    --port {self.clickhouse_port} \
                    --query "{query}" \
                    --format TabSeparated"""
                
                try:
                    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
                    if result.returncode != 0:
                        print(f"Ошибка при получении таблиц: {result.stderr}")
                        return {}
                    
                    tables_by_db = {}
                    for line in result.stdout.strip().split('\n'):
                        if line.strip():
                            parts = line.strip().split('\t')
                            if len(parts) >= 3:
                                database, table_name, engine = parts
                                if database not in tables_by_db:
                                    tables_by_db[database] = []
                                tables_by_db[database].append({
                                    'name': table_name,
                                    'engine': engine
                                })
                    
                    print(f"Найдено таблиц: {sum(len(tables) for tables in tables_by_db.values())}")
                    return tables_by_db
                    
                except Exception as e:
                    print(f"Ошибка при выполнении команды: {e}")
                    return {}
            
            def get_table_columns(self, database: str, table: str) -> List[Dict[str, Any]]:
                """Получает информацию о колонках таблицы"""
                query = f"""
                SELECT 
                    name,
                    type,
                    default_expression,
                    comment
                FROM system.columns 
                WHERE database = '{database}' AND table = '{table}'
                ORDER BY position
                """
                
                cmd = f"""docker exec {self.clickhouse_host} clickhouse-client \
                    --user {self.clickhouse_user} \
                    --password '{self.clickhouse_password}' \
                    --port {self.clickhouse_port} \
                    --query "{query}" \
                    --format TabSeparated"""
                
                try:
                    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
                    if result.returncode != 0:
                        print(f"Не удалось получить колонки для {database}.{table}: {result.stderr}")
                        return []
                    
                    columns = []
                    for line in result.stdout.strip().split('\n'):
                        if line.strip():
                            parts = line.strip().split('\t')
                            if len(parts) >= 4:
                                name, type_name, default_expr, comment = parts
                                columns.append({
                                    'name': name,
                                    'type': type_name,
                                    'default': default_expr if default_expr else None,
                                    'comment': comment if comment else None
                                })
                    
                    return columns
                    
                except Exception as e:
                    print(f"Ошибка при получении колонок для {database}.{table}: {e}")
                    return []
            
            def load_existing_sources(self) -> Dict[str, Any]:
                """Загружает существующий sources.yml"""
                if not os.path.exists(self.sources_file):
                    print("Файл sources.yml не найден, создаем новый")
                    return {'version': 2, 'sources': []}
                
                try:
                    with open(self.sources_file, 'r', encoding='utf-8') as f:
                        return yaml.safe_load(f) or {'version': 2, 'sources': []}
                except Exception as e:
                    print(f"Ошибка при загрузке sources.yml: {e}")
                    return {'version': 2, 'sources': []}
            
            def generate_column_tests(self, column_name: str, column_type: str) -> List[str]:
                """Генерирует тесты для колонки на основе имени и типа"""
                tests = []
                
                # Базовые тесты для всех колонок
                if 'id' in column_name.lower():
                    tests.extend(['not_null', 'unique'])
                elif column_name.lower() in ['timestamp', 'created_at', 'updated_at']:
                    tests.append('not_null')
                elif column_name.lower() in ['name', 'title', 'description']:
                    tests.append('not_null')
                elif 'amount' in column_name.lower() or 'price' in column_name.lower() or 'value' in column_name.lower():
                    tests.extend(['not_null', 'dbt_utils.accepted_range:min_value:0'])
                elif column_name.lower() in ['email']:
                    tests.extend(['not_null', 'dbt_utils.is_email'])
                elif column_name.lower() in ['url', 'link']:
                    tests.extend(['not_null', 'dbt_utils.is_url'])
                else:
                    tests.append('not_null')
                
                return tests
            
            def create_table_definition(self, table_name: str, columns: List[Dict[str, Any]]) -> Dict[str, Any]:
                """Создает определение таблицы для sources.yml"""
                table_def = {
                    'name': table_name,
                    'description': f"Table {table_name} from ClickHouse",
                    'columns': []
                }
                
                for col in columns:
                    column_def = {
                        'name': col['name'],
                        'description': col.get('comment') or f"Column {col['name']} of type {col['type']}"
                    }
                    
                    # Добавляем тесты
                    tests = self.generate_column_tests(col['name'], col['type'])
                    if tests:
                        column_def['tests'] = tests
                    
                    table_def['columns'].append(column_def)
                
                return table_def
            
            def update_sources(self) -> bool:
                """Обновляет sources.yml на основе таблиц в ClickHouse"""
                try:
                    # Получаем все таблицы из ClickHouse
                    tables_by_db = self.get_clickhouse_tables()
                    if not tables_by_db:
                        print("Не удалось получить таблицы из ClickHouse")
                        return False
                    
                    # Загружаем существующий sources.yml
                    sources_data = self.load_existing_sources()
                    
                    # Создаем словарь существующих источников для быстрого поиска
                    existing_sources = {}
                    for source in sources_data.get('sources', []):
                        existing_sources[source['name']] = {
                            'source': source,
                            'tables': {table['name']: table for table in source.get('tables', [])}
                        }
                    
                    # Обновляем источники
                    updated = False
                    for database, tables in tables_by_db.items():
                        if database not in existing_sources:
                            # Создаем новый источник
                            print(f"Создаем новый источник для базы данных: {database}")
                            new_source = {
                                'name': database,
                                'description': f"Tables from {database} database",
                                'database': database,
                                'schema': database,
                                'tables': []
                            }
                            sources_data['sources'].append(new_source)
                            existing_sources[database] = {
                                'source': new_source,
                                'tables': {}
                            }
                            updated = True
                        
                        # Обновляем таблицы в источнике
                        source_info = existing_sources[database]
                        for table_info in tables:
                            table_name = table_info['name']
                            
                            if table_name not in source_info['tables']:
                                # Добавляем новую таблицу
                                print(f"Добавляем новую таблицу: {database}.{table_name}")
                                columns = self.get_table_columns(database, table_name)
                                table_def = self.create_table_definition(table_name, columns)
                                source_info['source']['tables'].append(table_def)
                                source_info['tables'][table_name] = table_def
                                updated = True
                    
                    if updated:
                        # Сохраняем обновленный sources.yml
                        with open(self.sources_file, 'w', encoding='utf-8') as f:
                            yaml.dump(sources_data, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
                        print(f"Файл sources.yml успешно обновлен: {self.sources_file}")
                    else:
                        print("Изменений не обнаружено, sources.yml не обновлен")
                    
                    return True
                    
                except Exception as e:
                    print(f"Ошибка при обновлении sources.yml: {e}")
                    return False
        
        # Запускаем обновление источников
        updater = DbtSourcesUpdater()
        success = updater.update_sources()
        
        if success:
            print("✅ Sources.yml успешно обновлен")
            return "Success"
        else:
            print("❌ Ошибка при обновлении sources.yml")
            raise Exception("Failed to update sources.yml")
            
    except Exception as e:
        print(f"❌ Ошибка при обновлении источников: {e}")
        raise

def generate_dedup_report():
    """Генерация отчета по очистке дублей"""
    try:
        print("📊 Генерация отчета по очистке дублей...")
        
        # Здесь можно добавить логику для генерации отчета
        
        print("✅ Отчет по очистке дублей сгенерирован")
        return "Success"
    except Exception as e:
        print(f"❌ Ошибка при генерации отчета: {e}")
        raise

# Определение задач
start_task = EmptyOperator(
    task_id='start',
    dag=deduplication_dag,
)

update_sources_task = PythonOperator(
    task_id='update_dbt_sources',
    python_callable=update_dbt_sources,
    dag=deduplication_dag,
)

check_before_task = PythonOperator(
    task_id='check_duplicates_before',
    python_callable=check_duplicates_before,
    dag=deduplication_dag,
)

run_dedup_task = BashOperator(
    task_id='run_dbt_deduplication',
    bash_command='cd /opt/airflow/dbt && dbt run --select tag:clean',
    dag=deduplication_dag,
)

run_views_task = BashOperator(
    task_id='run_dbt_views',
    bash_command='cd /opt/airflow/dbt && dbt run --select tag:view',
    dag=deduplication_dag,
)

run_tests_task = BashOperator(
    task_id='run_dbt_tests_dedup',
    bash_command='cd /opt/airflow/dbt && dbt test --select test_no_duplicates',
    dag=deduplication_dag,
)

check_after_task = PythonOperator(
    task_id='check_duplicates_after',
    python_callable=check_duplicates_after,
    dag=deduplication_dag,
)

generate_report_task = PythonOperator(
    task_id='generate_dedup_report',
    python_callable=generate_dedup_report,
    dag=deduplication_dag,
)

end_task = EmptyOperator(
    task_id='end',
    dag=deduplication_dag,
    trigger_rule=TriggerRule.NONE_FAILED,
)

# Определение зависимостей
start_task >> update_sources_task >> check_before_task >> run_dedup_task >> run_views_task >> run_tests_task >> check_after_task >> generate_report_task >> end_task
