import clickhouse_connect
import os
from dotenv import load_dotenv

# Load environment variables
dotenv_path = os.path.join(os.path.dirname(__file__), '../infra/env/clickhouse.env')
load_dotenv(dotenv_path=dotenv_path)

class ClickHouseClient:
    """
    Утилита для работы с ClickHouse
    """
    def __init__(self):
        self.host = os.getenv("CLICKHOUSE_HOST", "localhost")
        self.port = int(os.getenv("CLICKHOUSE_PORT", "8123"))
        self.database = os.getenv("CLICKHOUSE_DATABASE", "energy_hub")
        self.username = os.getenv("CLICKHOUSE_USER", "default")
        self.password = os.getenv("CLICKHOUSE_PASSWORD", "")
        
        self.client = None
        self._connect()
    
    def _connect(self):
        """Установка соединения с ClickHouse"""
        try:
            self.client = clickhouse_connect.get_client(
                host=self.host,
                port=self.port,
                database=self.database,
                username=self.username,
                password=self.password
            )
            print(f"✅ Успешное подключение к ClickHouse: {self.host}:{self.port}")
        except Exception as e:
            print(f"❌ Ошибка подключения к ClickHouse: {e}")
            raise
    
    def execute_query(self, query: str, params: dict = None):
        """
        Выполнение SQL запроса
        
        Args:
            query (str): SQL запрос
            params (dict): Параметры для запроса
        
        Returns:
            dict: Результат выполнения запроса
        """
        try:
            if params:
                result = self.client.query(query, parameters=params)
            else:
                result = self.client.query(query)
            
            return {
                'success': True,
                'data': result.result_rows if hasattr(result, 'result_rows') else [],
                'rowcount': result.row_count if hasattr(result, 'row_count') else 0
            }
        except Exception as e:
            print(f"❌ Ошибка выполнения запроса: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def execute_command(self, command: str, params: dict = None):
        """
        Выполнение команды (INSERT, UPDATE, DELETE)
        
        Args:
            command (str): SQL команда
            params (dict): Параметры для команды
        
        Returns:
            dict: Результат выполнения команды
        """
        try:
            if params:
                result = self.client.command(command, parameters=params)
            else:
                result = self.client.command(command)
            
            return {
                'success': True,
                'result': result
            }
        except Exception as e:
            print(f"❌ Ошибка выполнения команды: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def close(self):
        """Закрытие соединения"""
        if self.client:
            self.client.close()
            print("🔌 Соединение с ClickHouse закрыто")

def execute_sql_script(sql_script: str, params: dict = None):
    """
    Удобная функция для выполнения SQL скрипта
    
    Args:
        sql_script (str): SQL скрипт для выполнения
        params (dict): Параметры для скрипта
    
    Returns:
        dict: Результат выполнения
    """
    client = ClickHouseClient()
    try:
        if sql_script.strip().upper().startswith('SELECT'):
            result = client.execute_query(sql_script, params)
        else:
            result = client.execute_command(sql_script, params)
        return result
    finally:
        client.close()
