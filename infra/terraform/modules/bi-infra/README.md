# BI-инфраструктура с Metabase и Superset на Terraform + PostgreSQL

## Архитектура решения

Этот проект разворачивает BI-инфраструктуру, включающую:

- **PostgreSQL** — централизованное хранилище для Metabase и Superset с раздельными пользователями и базами данных.
- **Metabase** — BI-сервис для аналитики с веб-интерфейсом.
- **Superset** — современный BI-инструмент с расширенными возможностями визуализации.
- **Terraform** — автоматизация деплоя всей инфраструктуры через конфигурационные файлы.

Каждый сервис использует отдельного пользователя и базу данных в PostgreSQL для безопасности и изоляции. Superset требует секретный ключ для работы и отдельный конфигурационный файл, который создаётся автоматически на основе шаблона.

Контейнеры запускаются с учётом порядка и проверки готовности через healthchecks, а для Superset автоматически создаётся администратор с заданными через переменные данными.

---

## Пользователи, создаваемые в Metabase и Superset

В процессе развертывания создаются следующие пользователи в Metabase и Superset. Логика создания пользователей и их данных реализована через `locals.tf` в переменных `locals.metabase_local_users` и `locals.superset_local_users`. Эти локальные переменные используют fallback-логику для значений, позволяя задавать общие креды или отдельные для каждого сервиса.

Если переменные `metabase_local_users` или `superset_local_users` не заданы явно, используются значения по умолчанию с fallback-логикой (см. locals.tf).

### Принцип fallback-логики для всех кредов

- Для каждого пользователя (админ/BI) можно задать общие переменные:  
  - `sa_username`, `sa_password` — общие имя и пароль администратора.  
  - `bi_username`, `bi_password` — общие имя и пароль BI-пользователя.  
- Если необходимо разделить креды между Metabase и Superset, используются специализированные переменные:  
  - Metabase админ: `metabase_sa_username`, `metabase_sa_password`  
  - Superset админ: `superset_sa_username`, `superset_sa_password`  
  - Metabase BI: `metabase_bi_username`, `metabase_bi_password`  
  - Superset BI: `superset_bi_username`, `superset_bi_password`  
- Если специализированные переменные не заданы, используется fallback на общие значения.  
- Для пароля PostgreSQL базы используется переменная `pg_password`.  
- Для более гибкой кастомизации состава пользователей можно задать переменные `metabase_local_users` и `superset_local_users` напрямую, описывая список пользователей с их параметрами (пример ниже).

Таким образом, можно гибко конфигурировать пользователей и их права для каждого сервиса отдельно, либо использовать общие креды для упрощения.

### Пример задания кастомных пользователей через переменные `*_local_users`

Для Superset:

```
superset_local_users = [
  {
    username   = "superset_admin"
    password   = "SuperPassword1"
    first_name = "Ivan"
    last_name  = "Admin"
    is_admin   = true
  },
  {
    username   = "superset_bi"
    password   = "BIPass2"
    first_name = "Boris"
    last_name  = "Analyst"
    is_admin   = false
  }
]
```

Для Metabase:

```
metabase_local_users = [
  {
    username   = "metabase_admin"
    password   = "MBPassword1"
    first_name = "Masha"
    last_name  = "Admin"
    email      = "metabase_admin@local.com"
  },
  {
    username   = "metabase_bi"
    password   = "BIMetabase2"
    first_name = "Ivan"
    last_name  = "User"
    email      = "metabase_bi@local.com"
  }
]
```

### Пользователи:

- **sa_user** (администратор, имя по умолчанию задаётся через переменную `sa_username` или специализированные):  
  — Полные права администратора.  
  — Используется для первичной настройки, управления сервисом, создания подключений и управления другими пользователями.  
  — Логин и пароль задаются через переменные с fallback-логикой (см. выше).  
  — Автоматически создаётся в обоих сервисах через `locals.metabase_local_users` и `locals.superset_local_users`, либо через кастомные переменные `metabase_local_users` и `superset_local_users`, если они заданы.  

- **bi_user** (пользователь BI, имя по умолчанию — `bi_user` или специализированные):  
  — Ограниченные права (только аналитика, построение дашбордов и отчётов).  
  — Имя и пароль задаются через переменные с fallback-логикой (см. выше).  
  — Автоматически создаётся в обоих сервисах через `locals.metabase_local_users` и `locals.superset_local_users`, либо через кастомные переменные `metabase_local_users` и `superset_local_users`, если они заданы.

**Обязательно задайте только те переменные, для которых нет значения по умолчанию (см. variables.tf). Все остальные переменные можно оставить дефолтными или переопределить через tfvars/environment.**

**Пароли для всех пользователей необходимо обязательно задавать через переменные окружения или файл tfvars, если для них нет значения по умолчанию.**

> **Обязательные переменные:**  
> Требуют явного задания только переменные **без значения по умолчанию**, включая:  
> - `pg_password` — пароль для PostgreSQL (используется как fallback для сервисных пользователей)  
> - `sa_username` и `sa_password` — общие админские креды (если не задаются специализированные)  
> - `bi_password` — пароль BI-пользователя (имя по умолчанию `bi_user`)  
> - `superset_secret_key` — уникальный секретный ключ для Superset (обязательно, без fallback)  
>  
> Все остальные переменные можно оставить дефолтными или переопределить при необходимости.

Минимальный набор переменных для запуска. Все остальные переменные могут быть заданы для кастомизации при необходимости (см. variables.tf), но обычно достаточно только этих.

```sh
# Минимальный набор переменных для запуска

export TF_VAR_pg_password="пароль_для_Postgres"               # обязательная переменная, используется как fallback для пользователей
export TF_VAR_sa_username="имя_админа"                        # обязательная переменная
export TF_VAR_sa_password="пароль_админа"                     # обязательная переменная
export TF_VAR_bi_password="пароль_BI_пользователя"            # обязательная переменная
export TF_VAR_superset_secret_key="уникальный_секретный_ключ" # обязательная переменная, без fallback, генерируется пользователем (например, openssl rand -base64 48 | tr -d '\n')

# Опционально можно задать имена пользователей:
# export TF_VAR_bi_username="bi_user"                         # по умолчанию 'bi_user'
# export TF_VAR_metabase_sa_username="metabase_admin"         # для изоляции пользователей Metabase
# export TF_VAR_superset_sa_username="superset_admin"         # для изоляции пользователей Superset
# Аналогично для bi_username и паролей.

# Для кастомизации состава пользователей можно задать переменные:
# export TF_VAR_metabase_local_users='[{"username":"metabase_admin","password":"MBPassword1","first_name":"Masha","last_name":"Admin","email":"metabase_admin@local.com"},{"username":"metabase_bi","password":"BIMetabase2","first_name":"Ivan","last_name":"User","email":"metabase_bi@local.com"}]'
# export TF_VAR_superset_local_users='[{"username":"superset_admin","password":"SuperPassword1","first_name":"Ivan","last_name":"Admin","is_admin":true},{"username":"superset_bi","password":"BIPass2","first_name":"Boris","last_name":"Analyst","is_admin":false}]'

# Все остальные переменные для Metabase и Superset задавайте только при необходимости кастомизации.
```

Если нужны разные значения паролей или логинов для разных сервисов, используйте специальные переменные (см. variables.tf).

---

## Структура проекта

```
additional/bi-infra/
├── main.tf                         # Основной Terraform-скрипт для деплоя
├── variables.tf                    # Описание всех переменных с типами и значениями по умолчанию
├── locals.tf                       # Локальные переменные с fallback-логикой для пользователей и паролей
├── outputs.tf                      # Вывод полезных значений после деплоя (адреса, креды)
├── README.md                       # Инструкция по установке и настройке
└── samples/
    └── superset/
        └── superset_config.py.tmpl # Шаблон конфигурации Superset с секретным ключом
```

---

## Пошаговый гайд по запуску

### 1. Подготовка переменных окружения или файла terraform.tfvars

Задайте необходимые переменные окружения в терминале или создайте файл `terraform.tfvars` с нужными значениями. Пример для shell:

```sh
export TF_VAR_pg_password="пароль_для_Postgres"               # обязательная переменная
export TF_VAR_sa_username="имя_админа"                        # обязательная переменная
export TF_VAR_sa_password="пароль_админа"                     # обязательная переменная
export TF_VAR_bi_password="пароль_BI_пользователя"            # обязательная переменная
export TF_VAR_superset_secret_key="уникальный_секретный_ключ" # обязательная переменная, генерируется пользователем
```

> Примечание: Superset требует уникальный секретный ключ для безопасности (обязательное условие, без fallback). Сгенерировать можно командой:
>
>   openssl rand -base64 48 | tr -d '\n'
>
> Вставьте полученный ключ в переменную TF_VAR_superset_secret_key.

Если хотите разделить креды между Metabase и Superset, задайте специализированные переменные, например:

```sh
export TF_VAR_metabase_sa_username="metabase_admin"
export TF_VAR_metabase_sa_password="пароль_metabase_admin"
export TF_VAR_superset_sa_username="superset_admin"
export TF_VAR_superset_sa_password="пароль_superset_admin"
```

Для более гибкой настройки состава пользователей можно задать переменные `metabase_local_users` и `superset_local_users` напрямую. Пример:

```sh
export TF_VAR_superset_local_users='[
  {
    "username": "superset_admin",
    "password": "SuperPassword1",
    "first_name": "Ivan",
    "last_name": "Admin",
    "is_admin": true
  },
  {
    "username": "superset_bi",
    "password": "BIPass2",
    "first_name": "Boris",
    "last_name": "Analyst",
    "is_admin": false
  }
]'
export TF_VAR_metabase_local_users='[
  {
    "username": "metabase_admin",
    "password": "MBPassword1",
    "first_name": "Masha",
    "last_name": "Admin",
    "email": "metabase_admin@local.com"
  },
  {
    "username": "metabase_bi",
    "password": "BIMetabase2",
    "first_name": "Ivan",
    "last_name": "User",
    "email": "metabase_bi@local.com"
  }
]'
```

### 2. Проверка переменных перед запуском

Перед запуском проверьте, что все необходимые переменные заданы:

```sh
env | grep TF_VAR_
```

Убедитесь, что обязательные переменные (`pg_password`, `sa_username`, `sa_password`, `bi_password`, `superset_secret_key`) присутствуют.

### 4. Инициализация Terraform

Перейдите в каталог проекта и инициализируйте Terraform:

```sh
cd additional/bi-infra
terraform init
```

### 5. Запуск деплоя

Запустите процесс развертывания:

```sh
terraform apply -auto-approve
```

#### Варианты запуска пайплайна

- Запуск обоих сервисов (Metabase и Superset):

  ```sh
  terraform apply -auto-approve
  ```

- Запуск только Metabase (Superset отключён):

  ```sh
  terraform apply -auto-approve -var="enable_metabase=true" -var="enable_superset=false"
  ```

- Запуск только Superset (Metabase отключён):

  ```sh
  terraform apply -auto-approve -var="enable_metabase=false" -var="enable_superset=true"
  ```

> В процессе развертывания автоматически выполняется **пост-инициализация** для обоих сервисов:  
> - **Superset**: создаётся конфиг с секретным ключом, автоматически добавляются администратор и BI-пользователь (с ролями admin и обычный пользователь) согласно `locals.superset_local_users` или кастомной переменной `superset_local_users`.  
> - **Metabase**: также автоматически создаются пользователи-администраторы и BI-пользователи по заданным логинам/паролям согласно `locals.metabase_local_users` или кастомной переменной `metabase_local_users` (без ручной регистрации через веб-интерфейс).  
>   
> Все параметры аутентификации берутся из переменных окружения или `terraform.tfvars` с fallback-логикой, описанной выше.  
> Адреса сервисов и учётные данные будут выведены после завершения деплоя.

### 6. Доступ к сервисам

- **Metabase:**  
  Открывайте в браузере http://localhost:3000 (порт можно изменить через переменную `TF_VAR_metabase_port`).  
  Для входа используйте логин и пароль администратора, которые были заданы в переменных (`sa_username`/`sa_password` или специализированные).  
  При первом запуске пользователи уже созданы автоматически.

- **Superset:**  
  Открывайте в браузере http://localhost:8088 (порт настраивается через `TF_VAR_superset_port`).  
  Вход по логину и паролю администратора (`sa_username`/`sa_password` или специализированные). Администратор создаётся автоматически с помощью post-init скрипта и секретного ключа.

---

## Устранение неполадок (Troubleshooting)

- **Порт уже занят:**  
  Измените значения переменных `TF_VAR_metabase_port` или `TF_VAR_superset_port` на свободные порты.

- **Superset не запускается:**  
  - Проверьте, что `TF_VAR_superset_secret_key` задан и содержит не менее 32 символов (обязательное условие, без fallback).  
  - Убедитесь, что администратор создан через post-init скрипт (проверьте логи Terraform и контейнеров).  
  - Посмотрите логи контейнера Superset:  
    ```sh
    docker logs <container_id_superset>
    ```

- **Данные PostgreSQL не сохраняются после перезапуска:**  
  По умолчанию используется эфемерный том. Для постоянного хранения данных настройте Docker volume в Terraform.

- **Ошибка подключения к базе:**  
  Проверьте правильность всех переменных, особенно паролей и имён пользователей (`TF_VAR_sa_username`, `TF_VAR_sa_password`, специализированные переменные и соответствующие пароли).  
  Помните, что все креды имеют fallback-логику через `locals.tf`. Если используете специализированные переменные, убедитесь, что они заданы корректно. Если нет, то используются общие переменные.

- **Общие рекомендации:**  
  - Перед запуском проверьте все переменные командой:  
    ```sh
    env | grep TF_VAR_
    ```  
  - Для просмотра логов контейнеров используйте `docker logs`.  
  - Если возникают ошибки Terraform, попробуйте выполнить `terraform destroy` и затем `terraform apply` заново.

---

## Сценарии использования и расширения

- Для добавления новых BI или ETL сервисов используйте общий PostgreSQL контейнер как backend, создавая новые пользователей и базы данных по необходимости.
- Для каждого сервиса задавайте уникальные имена баз данных через переменные.
- Healthchecks обеспечивают корректный порядок запуска контейнеров и сервисов.
- Рекомендуется настроить Docker volume для PostgreSQL, чтобы сохранить данные между перезапусками.
- Можно расширять конфигурацию Terraform для добавления мониторинга, бэкапов и других компонентов.

---

## Полезные ссылки

- [Terraform](https://www.terraform.io/) — инфраструктура как код  
- [Metabase](https://www.metabase.com/) — BI-инструмент  
- [Apache Superset](https://superset.apache.org/) — современный BI-инструмент  
- [PostgreSQL Docker Hub](https://hub.docker.com/_/postgres) — официальный образ PostgreSQL  
- [Генерация секретных ключей OpenSSL](https://www.openssl.org/docs/man1.1.1/man1/openssl-rand.html)  

---

Если у вас возникнут вопросы или проблемы, пожалуйста, внимательно проверьте переменные окружения и логи контейнеров. Этот проект создан для максимально простого и безопасного развертывания BI-инфраструктуры с помощью Terraform.