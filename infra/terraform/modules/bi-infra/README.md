# Terraform Module: BI Infrastructure (Metabase & Superset)

## Архитектура

Этот модуль Terraform разворачивает гибкую и изолированную BI-инфраструктуру на Docker, включающую:

- **PostgreSQL**: Централизованное хранилище метаданных для Metabase и Superset. Для каждого BI-инструмента создается отдельная база данных и пользователь, что обеспечивает изоляцию и безопасность.
- **Metabase (опционально)**: Популярный BI-инструмент для быстрой аналитики и построения дашбордов. Включается флагом `deploy_metabase`.
- **Apache Superset (опционально)**: Мощная и современная BI-платформа с расширенными возможностями визуализации. Включается флагом `deploy_superset`.

Модуль спроектирован для легкой интеграции и настройки. Он автоматически выполняет первоначальную настройку, включая создание пользователей и баз данных в Postgres, а также инициализацию самих BI-сервисов через их API, избавляя от необходимости ручной настройки после развертывания.

---

## Управление пользователями и аутентификацией

Логика создания пользователей и их учетных данных реализована в `locals.tf`. Она использует **fallback-механизм**, позволяя задавать как общие учетные данные для всех сервисов, так и специфичные для каждого.

### Принцип Fallback-логики

- **Общие переменные**: `sa_username`, `sa_password`, `bi_user`, `bi_password`.
- **Специфичные переменные**: `metabase_sa_username`, `superset_sa_password` и т.д. Если специфичная переменная не задана (равна `null`), используется значение из соответствующей общей переменной.
- **Пароли Postgres**: Для пользователей `metabase` и `superset` в Postgres также используется fallback на общий пароль `pg_password`.

Это позволяет легко управлять доступом: можно использовать единые креды для простоты или разделить их для повышения безопасности.

### Кастомизация пользователей

Для полной кастомизации можно передать список пользователей через переменные `metabase_local_users` и `superset_local_users` в формате списка объектов.

**Пример для `terraform.tfvars`:**
```hcl
# Кастомные пользователи для Superset
superset_local_users = [
  {
    username   = "s_admin"
    password   = "SuperPassword1"
    first_name = "Ivan"
    last_name  = "Admin"
    is_admin   = true
  },
  {
    username   = "s_analyst"
    password   = "BIPass2"
    first_name = "Boris"
    last_name  = "Analyst"
    is_admin   = false
  }
]

# Кастомные пользователи для Metabase
metabase_local_users = [
  {
    username   = "m_admin"
    password   = "MBPassword1"
    first_name = "Masha"
    last_name  = "Admin"
    email      = "m_admin@local.com"
  }
]
```

---

## Входные переменные (Input Variables)

| Имя | Описание |
| --- | --- |
| `deploy_metabase` | `bool` - Развернуть Metabase. |
| `deploy_superset` | `bool` - Развернуть Apache Superset. |
| `postgres_version` | `string` - Версия Docker-образа Postgres. |
| `metabase_version` | `string` - Версия Docker-образа Metabase. |
| `superset_version` | `string` - Версия Docker-образа Superset. |
| `metabase_port` | `number` - Порт для UI Metabase на хосте. |
| `superset_port` | `number` - Порт для UI Superset на хосте. |
| `bi_postgres_data_path`| `string` - Путь к директории с данными Postgres. |
| `pg_password` | `string` - (Sensitive) Общий пароль для пользователей Postgres. |
| `sa_username` | `string` - Общее имя администратора для BI-инструментов. |
| `sa_password` | `string` - (Sensitive) Общий пароль администратора. |
| `bi_user` | `string` - Общий логин BI-пользователя. |
| `bi_password` | `string` - (Sensitive) Общий пароль BI-пользователя. |
| `superset_secret_key` | `string` - (Sensitive) Обязательный секретный ключ для Superset. |
| ...и другие | См. `variables.tf` для полного списка, включая специфичные для сервисов креды и настройки. |

---

## Доступ к сервисам

После успешного выполнения `terraform apply`:

- **Metabase:**
  - **URL:** `http://localhost:<metabase_port>` (по умолчанию `3000`).
  - **Вход:** Используйте учетные данные администратора, заданные в `terraform.tfvars`.

- **Superset:**
  - **URL:** `http://localhost:<superset_port>` (по умолчанию `8088`).
  - **Вход:** Используйте учетные данные администратора, заданные в `terraform.tfvars`.

---

## Устранение неполадок (Troubleshooting)

- **Порт уже занят:** Измените значения `metabase_port` или `superset_port` в вашем `terraform.tfvars`.
- **Сервис не запускается:**
  - **Superset:** Проверьте, что `superset_secret_key` задан и является уникальной, длинной строкой.
  - **Пароли:** Убедитесь, что все обязательные пароли (`pg_password`, `sa_password` и т.д.) заданы.
  - **Логи:** `docker logs metabase` или `docker logs superset` — лучший способ диагностики.
- **Ошибка `local-exec provisioner error`:** Чаще всего это "гонка состояний", когда один сервис пытается обратиться к другому, который еще не успел полностью запуститься. В скрипты встроены циклы ожидания. Если ошибка повторяется, попробуйте запустить `terraform apply` еще раз.

---

## Сценарии использования и расширения

- **Легковесный BI:** Отключите Superset (`deploy_superset = false`), чтобы развернуть только Metabase.
- **Мощная визуализация:** Отключите Metabase (`deploy_metabase = false`) для использования только Superset.
- **Интеграция с другими сервисами:** Используйте созданную Docker-сеть для подключения других контейнеров (например, Airflow) к базе данных Postgres.
- **Кастомизация Superset:** Файл `superset_config.py` генерируется из шаблона. Вы можете расширить `samples/superset/superset_config.py.tmpl` для добавления собственных настроек, например, кастомных драйверов баз данных.

---

## Полезные ссылки

- [Terraform](https://www.terraform.io/)
- [Metabase](https://www.metabase.com/)
- [Apache Superset](https://superset.apache.org/)
- [PostgreSQL Docker Hub](https://hub.docker.com/_/postgres)
