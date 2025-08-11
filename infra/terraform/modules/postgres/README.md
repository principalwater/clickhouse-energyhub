# Terraform Module: PostgreSQL

## Архитектура

Этот модуль Terraform разворачивает централизованную платформу PostgreSQL для всех сервисов проекта EnergyHub. Архитектура включает:

- **PostgreSQL**: Единый экземпляр базы данных для всех сервисов
- **Изолированные пользователи**: Отдельные пользователи и базы данных для каждого сервиса
- **Автоматическое управление**: Создание пользователей, баз данных и настройка прав доступа
- **Гибкость развертывания**: Возможность включения/отключения поддержки отдельных сервисов

### Поддерживаемые сервисы

- **Metabase**: BI-инструмент для визуализации данных
- **Apache Superset**: Мощная BI-платформа
- **Apache Airflow**: Платформа для оркестрации задач

---

## Особенности

### Централизованное управление
- Единый экземпляр PostgreSQL для всех сервисов
- Автоматическое создание пользователей и баз данных
- Настройка прав доступа и привилегий

### Изоляция данных
- Каждый сервис получает отдельного пользователя
- Отдельные базы данных для каждого сервиса
- Контролируемые права доступа

### Production-ready
- Health checks для контейнера
- Персистентное хранение данных
- Возможность восстановления из бэкапов

---

## Входные переменные (Input Variables)

### Основные настройки
| Имя | Описание | Тип | По умолчанию |
| --- | --- | --- | --- |
| `enable_postgres` | Включить PostgreSQL | `bool` | `true` |
| `postgres_version` | Версия Docker-образа PostgreSQL | `string` | `"16"` |
| `postgres_data_path` | Путь к данным PostgreSQL | `string` | `"../../volumes/postgres/data"` |
| `postgres_superuser_password` | Пароль суперпользователя | `string` | **Обязательно** |
| `postgres_restore_enabled` | Включить восстановление | `bool` | `true` |

### Флаги сервисов
| Имя | Описание | Тип | По умолчанию |
| --- | --- | --- | --- |
| `enable_metabase` | Включить поддержку Metabase | `bool` | `false` |
| `enable_superset` | Включить поддержку Superset | `bool` | `false` |
| `enable_airflow` | Включить поддержку Airflow | `bool` | `false` |

### Metabase настройки
| Имя | Описание | Тип | По умолчанию |
| --- | --- | --- | --- |
| `metabase_pg_user` | Пользователь Metabase | `string` | `"metabase"` |
| `metabase_pg_password` | Пароль Metabase | `string` | **Обязательно** |
| `metabase_pg_db` | База данных Metabase | `string` | `"metabaseappdb"` |

### Superset настройки
| Имя | Описание | Тип | По умолчанию |
| --- | --- | --- | --- |
| `superset_pg_user` | Пользователь Superset | `string` | `"superset"` |
| `superset_pg_password` | Пароль Superset | `string` | **Обязательно** |
| `superset_pg_db` | База данных Superset | `string` | `"superset"` |

### Airflow настройки
| Имя | Описание | Тип | По умолчанию |
| --- | --- | --- | --- |
| `airflow_pg_user` | Пользователь Airflow | `string` | `"airflow"` |
| `airflow_pg_password` | Пароль Airflow | `string` | **Обязательно** |
| `airflow_pg_db` | База данных Airflow | `string` | `"airflow"` |

---

## Выходные значения (Outputs)

### Основная информация
| Имя | Описание |
| --- | --- |
| `postgres_container_name` | Имя контейнера PostgreSQL |
| `postgres_network_name` | Имя Docker-сети PostgreSQL |
| `postgres_host` | Хост PostgreSQL |
| `postgres_port` | Порт PostgreSQL |
| `postgres_superuser` | Имя суперпользователя |
| `postgres_connection_string` | Строка подключения суперпользователя |

### Metabase
| Имя | Описание |
| --- | --- |
| `metabase_db_connection_string` | Строка подключения к БД Metabase |
| `metabase_db_creds` | Учетные данные Metabase |

### Superset
| Имя | Описание |
| --- | --- |
| `superset_db_connection_string` | Строка подключения к БД Superset |
| `superset_db_creds` | Учетные данные Superset |

### Airflow
| Имя | Описание |
| --- | --- |
| `airflow_db_connection_string` | Строка подключения к БД Airflow |
| `airflow_db_creds` | Учетные данные Airflow |

---

## Автоматическое управление

### Создание пользователей
Модуль автоматически создает пользователей PostgreSQL для каждого включенного сервиса:
- Проверка существования пользователя
- Создание нового пользователя или обновление пароля
- Настройка прав доступа

### Создание баз данных
Для каждого сервиса создается отдельная база данных:
- Проверка существования базы данных
- Создание новой базы данных при необходимости
- Настройка прав доступа для пользователя сервиса

### Настройка прав
Каждый пользователь получает необходимые права:
- `CREATE` и `USAGE` на схему `public`
- `CREATE` на базу данных сервиса

---

## Сценарии использования

### Базовое развертывание
```hcl
module "postgres" {
  source = "./modules/postgres"
  
  enable_postgres = true
  postgres_superuser_password = "your_superuser_password"
  
  # Включить поддержку сервисов
  enable_metabase = true
  enable_superset = true
  enable_airflow = true
  
  # Пароли для сервисов
  metabase_pg_password = "metabase_password"
  superset_pg_password = "superset_password"
  airflow_pg_password = "airflow_password"
}
```

### Только для BI-инструментов
```hcl
module "postgres" {
  source = "./modules/postgres"
  
  enable_postgres = true
  postgres_superuser_password = "your_superuser_password"
  
  # Только BI-инструменты
  enable_metabase = true
  enable_superset = true
  enable_airflow = false
  
  metabase_pg_password = "metabase_password"
  superset_pg_password = "superset_password"
}
```

### Только для Airflow
```hcl
module "postgres" {
  source = "./modules/postgres"
  
  enable_postgres = true
  postgres_superuser_password = "your_superuser_password"
  
  # Только Airflow
  enable_metabase = false
  enable_superset = false
  enable_airflow = true
  
  airflow_pg_password = "airflow_password"
}
```

---

## Интеграция с другими модулями

### Модуль bi-infra
```hcl
module "bi_infra" {
  source = "./modules/bi-infra"
  
  # Использовать PostgreSQL из модуля postgres
  postgres_container_name = module.postgres.postgres_container_name
  postgres_network_name = module.postgres.postgres_network_name
  
  # ... остальные параметры
}
```

### Модуль airflow
```hcl
module "airflow" {
  source = "./modules/airflow"
  
  # Использовать PostgreSQL из модуля postgres
  airflow_postgres_connection_string = module.postgres.airflow_db_connection_string
  
  # ... остальные параметры
}
```

---

## Устранение неполадок

### Общие проблемы

- **PostgreSQL не запускается:**
  - Проверьте логи: `docker logs postgres`
  - Убедитесь, что порт 5432 свободен
  - Проверьте права доступа к директории данных

- **Ошибки создания пользователей:**
  - Убедитесь, что PostgreSQL полностью запущен
  - Проверьте правильность паролей
  - Проверьте логи provisioner'ов

### Полезные команды

```bash
# Проверка статуса контейнера
docker ps -a | grep postgres

# Просмотр логов
docker logs postgres

# Подключение к PostgreSQL
docker exec -it postgres psql -U postgres

# Список пользователей
docker exec -it postgres psql -U postgres -c "\du"

# Список баз данных
docker exec -it postgres psql -U postgres -c "\l"
```

---

## Полезные ссылки

- [PostgreSQL](https://www.postgresql.org/)
- [PostgreSQL Docker Hub](https://hub.docker.com/_/postgres)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Terraform](https://www.terraform.io/)
