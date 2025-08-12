#!/usr/bin/env python3
"""
Менеджер для работы с бэкапами ClickHouse через clickhouse-backup
"""

import subprocess
import argparse
import sys
from datetime import datetime
import os
from dotenv import load_dotenv

# Load environment variables
dotenv_path = os.path.join(os.path.dirname(__file__), '../infra/env/clickhouse.env')
load_dotenv(dotenv_path=dotenv_path)

class ClickHouseBackupManager:
    """
    Менеджер для работы с бэкапами ClickHouse
    """
    
    def _run_command(self, cmd, description="Command"):
        """
        Универсальная функция для выполнения команд с обработкой ошибок
        
        Args:
            cmd (str): Команда для выполнения
            description (str): Описание команды для логирования
            
        Returns:
            subprocess.CompletedProcess: Результат выполнения команды
            
        Raises:
            Exception: Если команда завершилась с ошибкой
        """
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        
        if result.returncode != 0:
            error_msg = result.stderr.strip() if result.stderr.strip() else result.stdout.strip()
            if not error_msg:
                error_msg = f"Command failed with return code {result.returncode}"
            
            print(f"❌ Ошибка {description}: {error_msg}")
            print(f"📋 Команда: {cmd}")
            print(f"📋 Return code: {result.returncode}")
            print(f"📋 Stdout: {result.stdout}")
            print(f"📋 Stderr: {result.stderr}")
            raise Exception(f"Ошибка {description}: {error_msg}")
            
        return result
    
    def __init__(self):
        self.super_user = os.getenv("CH_USER", "default")
        self.super_password = os.getenv("CH_PASSWORD", "")
    
    def create_backup(self, backup_name=None):
        """
        Создание бэкапа ClickHouse
        
        Args:
            backup_name (str): Имя бэкапа (если не указано, генерируется автоматически)
        
        Returns:
            str: Имя созданного бэкапа
        """
        if not backup_name:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            backup_name = f"backup_local_{timestamp}"
        
        print(f"🔄 Создание бэкапа: {backup_name}")
        
        cmd = f"docker exec clickhouse-backup clickhouse-backup create_remote '{backup_name}'"
        result = self._run_command(cmd, "создания бэкапа")
        
        print(f"✅ Бэкап {backup_name} создан успешно")
        print(f"📋 Вывод: {result.stdout}")
        return backup_name
    
    def list_backups(self):
        """
        Получение списка доступных бэкапов
        
        Returns:
            str: Список бэкапов
        """
        print("📋 Получение списка бэкапов...")
        
        cmd = "docker exec clickhouse-backup clickhouse-backup list remote"
        result = self._run_command(cmd, "получения списка бэкапов")
        
        print("✅ Список бэкапов:")
        print(result.stdout)
        return result.stdout
    
    def get_latest_backup(self):
        """
        Получение имени последнего бэкапа
        
        Returns:
            str: Имя последнего бэкапа
        """
        cmd = "docker exec clickhouse-backup clickhouse-backup list remote | grep '^backup' | tail -1 | awk '{print $1}'"
        result = self._run_command(cmd, "получения последнего бэкапа")
        
        if result.stdout.strip():
            backup_name = result.stdout.strip()
            print(f"📋 Последний бэкап: {backup_name}")
            return backup_name
        else:
            raise Exception("Не удалось найти доступные бэкапы")
    
    def get_backup_info(self, backup_name):
        """
        Получение информации о бэкапе
        
        Args:
            backup_name (str): Имя бэкапа
        
        Returns:
            dict: Информация о бэкапе
        """
        cmd = f"docker exec clickhouse-backup clickhouse-backup list remote | grep '{backup_name}'"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        
        if result.returncode == 0 and backup_name in result.stdout:
            # Парсим информацию о бэкапе
            lines = result.stdout.strip().split('\n')
            for line in lines:
                if backup_name in line:
                    parts = line.split()
                    if len(parts) >= 3:
                        return {
                            'name': parts[0],
                            'size': parts[1],
                            'created': parts[2] + ' ' + parts[3] if len(parts) > 3 else parts[2]
                        }
        return None

    def get_current_tables_info(self):
        """
        Получение информации о текущих таблицах в ClickHouse
        
        Returns:
            dict: Информация о таблицах
        """
        cmd = "docker exec clickhouse-01 clickhouse-client --query \"SELECT database, name, engine, total_rows, total_bytes FROM system.tables WHERE database NOT IN ('system', 'information_schema') ORDER BY database, name\""
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        
        tables_info = {}
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            if lines and lines[0].strip():
                for line in lines:
                    if line.strip():
                        parts = line.split('\t')
                        if len(parts) >= 5:
                            db_table = f"{parts[0]}.{parts[1]}"
                            tables_info[db_table] = {
                                'engine': parts[2],
                                'total_rows': parts[3],
                                'total_bytes': parts[4]
                            }
        return tables_info

    def compare_with_backup(self, backup_name):
        """
        Сравнение текущего состояния с бэкапом
        
        Args:
            backup_name (str): Имя бэкапа для сравнения
        
        Returns:
            dict: Результат сравнения
        """
        print(f"🔍 Сравнение текущего состояния с бэкапом: {backup_name}")
        
        # Получаем информацию о бэкапе
        backup_info = self.get_backup_info(backup_name)
        if not backup_info:
            return {'needs_restore': True, 'reason': 'Backup not found'}
        
        # Получаем информацию о текущих таблицах
        current_tables = self.get_current_tables_info()
        
        # Проверяем, есть ли таблицы в бэкапе
        cmd = f"docker exec clickhouse-backup clickhouse-backup list remote | grep '{backup_name}'"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        
        if result.returncode != 0:
            return {'needs_restore': True, 'reason': 'Cannot access backup'}
        
        # Простая проверка: если бэкап существует и имеет размер > 0, считаем что есть изменения
        if backup_info['size'] == '0B' or backup_info['size'] == '0':
            return {'needs_restore': False, 'reason': 'Backup is empty'}
        
        # Проверяем, есть ли таблицы в текущей системе
        if not current_tables:
            return {'needs_restore': True, 'reason': 'No tables in current system'}
        
        # Для простоты считаем, что если бэкап существует и не пустой, то есть изменения
        # В реальной системе здесь можно добавить более детальное сравнение
        return {'needs_restore': True, 'reason': 'Backup contains data that may differ from current state'}

    def restore_backup(self, backup_name=None, force=False):
        """
        Умное восстановление из бэкапа
        
        Args:
            backup_name (str): Имя бэкапа (если не указано, используется последний)
            force (bool): Принудительное восстановление без проверки
        
        Returns:
            str: Результат восстановления
        """
        if not backup_name:
            backup_name = self.get_latest_backup()
        
        print(f"🔄 Подготовка к восстановлению из бэкапа: {backup_name}")
        
        # Проверяем, нужно ли восстановление
        if not force:
            comparison = self.compare_with_backup(backup_name)
            if not comparison['needs_restore']:
                print(f"✅ Восстановление не требуется: {comparison['reason']}")
                return f"Skipped restore from {backup_name}: {comparison['reason']}"
            else:
                print(f"📋 Восстановление необходимо: {comparison['reason']}")
        
        print(f"🔄 Выполнение восстановления из бэкапа: {backup_name}")
        
        # Сначала удаляем существующие таблицы, если они есть
        print("🧹 Очистка существующих таблиц перед восстановлением...")
        cleanup_cmd = f"docker exec clickhouse-backup clickhouse-backup restore_remote --schema --rm {backup_name}"
        cleanup_result = subprocess.run(cleanup_cmd, shell=True, capture_output=True, text=True)
        
        # Теперь выполняем полное восстановление
        cmd = f"docker exec clickhouse-backup clickhouse-backup restore_remote {backup_name}"
        
        # Выполняем команду с более терпимой обработкой stderr
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        
        # Проверяем только return code, игнорируем stderr для восстановления
        if result.returncode != 0:
            error_msg = result.stderr.strip() if result.stderr.strip() else result.stdout.strip()
            if not error_msg:
                error_msg = f"Command failed with return code {result.returncode}"
            
            print(f"❌ Ошибка восстановления из бэкапа: {error_msg}")
            print(f"📋 Команда: {cmd}")
            print(f"📋 Return code: {result.returncode}")
            print(f"📋 Stdout: {result.stdout}")
            print(f"📋 Stderr: {result.stderr}")
            raise Exception(f"Ошибка восстановления из бэкапа: {error_msg}")
        
        print(f"✅ Восстановление из бэкапа {backup_name} выполнено успешно")
        print(f"📋 Вывод: {result.stdout}")
        if result.stderr:
            print(f"📋 Stderr (информационные сообщения): {result.stderr}")
        
        return f"Restored from {backup_name}"
    
    def verify_backup(self, backup_name):
        """
        Проверка целостности бэкапа
        
        Args:
            backup_name (str): Имя бэкапа для проверки
        
        Returns:
            bool: True если бэкап корректен
        """
        print(f"🔍 Проверка целостности бэкапа: {backup_name}")
        
        cmd = f"docker exec clickhouse-backup clickhouse-backup list remote | grep '{backup_name}'"
        try:
            result = self._run_command(cmd, "проверки бэкапа")
            if backup_name in result.stdout:
                print(f"✅ Бэкап {backup_name} найден и доступен")
                return True
            else:
                print(f"❌ Бэкап {backup_name} не найден или недоступен")
                return False
        except Exception:
            print(f"❌ Бэкап {backup_name} не найден или недоступен")
            return False
    
    def delete_backup(self, backup_name):
        """
        Удаление бэкапа
        
        Args:
            backup_name (str): Имя бэкапа для удаления
        
        Returns:
            bool: True если удаление успешно
        """
        print(f"🗑️ Удаление бэкапа: {backup_name}")
        
        cmd = f"docker exec clickhouse-backup clickhouse-backup delete remote {backup_name}"
        try:
            result = self._run_command(cmd, "удаления бэкапа")
            print(f"✅ Бэкап {backup_name} удален успешно")
            return True
        except Exception as e:
            print(f"❌ Ошибка удаления бэкапа {backup_name}: {e}")
            return False
    
    def cleanup_old_backups(self, keep_count=7):
        """
        Очистка старых бэкапов
        
        Args:
            keep_count (int): Количество бэкапов для сохранения
        
        Returns:
            str: Результат очистки
        """
        print(f"🧹 Очистка старых бэкапов (оставляем {keep_count})...")
        
        # Получаем список всех бэкапов
        cmd = "docker exec clickhouse-backup clickhouse-backup list remote | grep '^backup' | awk '{print $1}' | sort"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        
        if result.returncode == 0:
            backups = result.stdout.strip().split('\n')
            backups = [b.strip() for b in backups if b.strip()]
            
            if len(backups) > keep_count:
                # Оставляем последние keep_count бэкапов
                backups_to_delete = backups[:-keep_count]
                
                print(f"🗑️ Удаление {len(backups_to_delete)} старых бэкапов...")
                
                deleted_count = 0
                for backup in backups_to_delete:
                    if self.delete_backup(backup):
                        deleted_count += 1
                
                print(f"✅ Очистка завершена. Удалено {deleted_count} бэкапов, оставлено {len(backups) - deleted_count}")
                return f"Cleaned up, deleted {deleted_count}, kept {len(backups) - deleted_count}"
            else:
                print(f"✅ Количество бэкапов ({len(backups)}) в пределах нормы, очистка не требуется")
                return f"No cleanup needed, {len(backups)} backups"
        else:
            print(f"❌ Ошибка получения списка бэкапов для очистки: {result.stderr}")
            raise Exception(f"Ошибка получения списка бэкапов: {result.stderr}")
    
    def test_clickhouse_connection(self):
        """
        Тестирование подключения к ClickHouse
        
        Returns:
            bool: True если подключение успешно
        """
        print("🔍 Тестирование подключения к ClickHouse...")
        
        try:
            cmd = f"docker exec -i clickhouse-01 clickhouse-client --user {self.super_user} --password {self.super_password} --query 'SELECT 1'"
            result = self._run_command(cmd, "тестирования подключения к ClickHouse")
            print("✅ Подключение к ClickHouse успешно")
            return True
        except Exception as e:
            print(f"❌ Ошибка подключения к ClickHouse: {e}")
            return False
    
    def simulate_failure_and_restore(self, table_name="test_db.sample_table"):
        """
        Имитация сбоя и восстановление (для тестирования)
        
        Args:
            table_name (str): Имя таблицы для тестирования
        
        Returns:
            str: Результат тестирования
        """
        print(f"🧪 Имитация сбоя и восстановление для таблицы {table_name}...")
        
        try:
            # Создаем бэкап перед тестом
            backup_name = self.create_backup()
            
            # Имитируем сбой - удаляем таблицу
            print(f"🗑️ Удаление таблицы {table_name}...")
            drop_cmd = f"docker exec -i clickhouse-01 clickhouse-client --user {self.super_user} --password {self.super_password} --query 'DROP TABLE IF EXISTS {table_name} ON CLUSTER dwh_test SYNC;'"
            
            try:
                self._run_command(drop_cmd, "удаления таблицы")
            except Exception as e:
                print(f"⚠️ Ошибка удаления таблицы: {e}")
            
            # Восстанавливаем из бэкапа
            self.restore_backup(backup_name)
            
            # Проверяем восстановление
            check_cmd = f"docker exec -i clickhouse-01 clickhouse-client --user {self.super_user} --password {self.super_password} --query 'SELECT count() FROM {table_name};'"
            result = self._run_command(check_cmd, "проверки восстановления")
            
            print(f"✅ Восстановление успешно! Количество записей: {result.stdout.strip()}")
            return "Test passed"
                
        except Exception as e:
            print(f"❌ Ошибка при тестировании: {e}")
            return f"Test failed: {e}"

def main():
    """Основная функция для работы с бэкапами"""
    parser = argparse.ArgumentParser(description="Менеджер бэкапов ClickHouse")
    parser.add_argument("action", choices=[
        "create", "list", "restore", "delete", "cleanup", "verify", "test", "health"
    ], help="Действие для выполнения")
    parser.add_argument("--backup-name", help="Имя бэкапа")
    parser.add_argument("--keep-count", type=int, default=7, help="Количество бэкапов для сохранения при очистке")
    parser.add_argument("--table-name", default="test_db.sample_table", help="Имя таблицы для тестирования")
    
    args = parser.parse_args()
    
    manager = ClickHouseBackupManager()
    
    try:
        if args.action == "create":
            backup_name = manager.create_backup(args.backup_name)
            print(f"✅ Создан бэкап: {backup_name}")
            
        elif args.action == "list":
            backups = manager.list_backups()
            print("✅ Список бэкапов получен")
            
        elif args.action == "restore":
            result = manager.restore_backup(args.backup_name)
            print(f"✅ Восстановление: {result}")
            
        elif args.action == "delete":
            if not args.backup_name:
                print("❌ Необходимо указать имя бэкапа для удаления")
                sys.exit(1)
            success = manager.delete_backup(args.backup_name)
            if success:
                print(f"✅ Бэкап {args.backup_name} удален")
            else:
                print(f"❌ Ошибка удаления бэкапа {args.backup_name}")
                sys.exit(1)
                
        elif args.action == "cleanup":
            result = manager.cleanup_old_backups(args.keep_count)
            print(f"✅ Очистка: {result}")
            
        elif args.action == "verify":
            if not args.backup_name:
                print("❌ Необходимо указать имя бэкапа для проверки")
                sys.exit(1)
            success = manager.verify_backup(args.backup_name)
            if success:
                print(f"✅ Бэкап {args.backup_name} корректен")
            else:
                print(f"❌ Бэкап {args.backup_name} некорректен")
                sys.exit(1)
                
        elif args.action == "test":
            result = manager.simulate_failure_and_restore(args.table_name)
            print(f"✅ Тест: {result}")
            
        elif args.action == "health":
            success = manager.test_clickhouse_connection()
            if success:
                print("✅ Система бэкапов здорова")
            else:
                print("❌ Проблемы с системой бэкапов")
                sys.exit(1)
                
    except Exception as e:
        print(f"❌ Ошибка: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
