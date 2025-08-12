# Terraform Module: ClickHouse Cluster

Этот модуль разворачивает полноценный, готовый к работе кластер ClickHouse с использованием Docker. Он включает в себя несколько нод ClickHouse, настроенных для репликации и шардирования, а также кластер ClickHouse Keeper для координации.

## Архитектура

Модуль создает следующие компоненты:
- **Docker Network:** Изолированная сеть `clickhouse-net` для всех компонентов кластера.
- **ClickHouse Keeper Nodes:** 3 ноды Keeper для обеспечения кворума и управления репликацией.
- **ClickHouse Server Nodes:** 4 ноды ClickHouse, сгруппированные в 2 шарда по 2 реплики в каждом.
- **MinIO (S3) Storage (Опционально):**
    - **Локальное S3-хранилище:** MinIO контейнер для эмуляции S3 для основного хранения данных (режим `storage_type = "s3_ssd"`).
    - **Удаленное S3-хранилище для бэкапов:** MinIO контейнер, который может быть развернут на удаленном хосте по SSH.
    - **Локальное S3-хранилище для бэкапов:** MinIO контейнер, который разворачивается локально (режим `storage_type = "local_storage"`).
- **ClickHouse Backup:** Контейнер с утилитой `clickhouse-backup` для создания и восстановления резервных копий.

## Входные переменные (Input Variables)

| Имя                        | Описание                                                                        | Тип      |
|----------------------------|---------------------------------------------------------------------------------|-----------|
| `clickhouse_base_path`    | Базовый путь для данных и конфигураций ClickHouse.                             | `string`  |
| `bi_postgres_data_path`   | Путь к данным Postgres для BI-инструментов.                                    | `string`  |
| `memory_limit`             | Ограничение по памяти для контейнеров ClickHouse.                              | `number`  |
| `super_user_name`          | Имя основного пользователя ClickHouse.                                         | `string`  |
| `bi_user_name`             | Имя BI-пользователя ClickHouse (readonly).                                     | `string`  |
| `super_user_password`      | Пароль для super_user.                                                         | `string`  |
| `bi_user_password`         | Пароль для bi_user.                                                            | `string`  |
| `ch_version`               | Версия ClickHouse server.                                                      | `string`  |
| `chk_version`              | Версия ClickHouse keeper.                                                      | `string`  |
| `minio_version`            | Версия MinIO.                                                                  | `string`  |
| `ch_uid`                   | UID для пользователя clickhouse в контейнере.                                  | `string`  |
| `ch_gid`                   | GID для пользователя clickhouse в контейнере.                                  | `string`  |
| `use_standard_ports`       | Использовать стандартные порты для всех нод ClickHouse.                         | `bool`    |
| `ch_http_port`             | Стандартный HTTP порт для ClickHouse.                                          | `number`  |
| `ch_tcp_port`              | Стандартный TCP порт для ClickHouse.                                           | `number`  |
| `ch_replication_port`      | Стандартный порт репликации для ClickHouse.                                    | `number`  |
| `minio_root_user`          | Пользователь для доступа к MinIO.                                              | `string`  |
| `minio_root_password`      | Пароль для доступа к MinIO.                                                    | `string`  |
| `remote_ssh_user`          | Имя пользователя для SSH-доступа к удаленному хосту.                            | `string`  |
| `ssh_private_key_path`     | Путь к приватному SSH-ключу.                                                   | `string`  |
| `local_minio_port`         | Порт для локального MinIO (для `s3_ssd`).                                     | `number`  |
| `remote_minio_port`        | Порт для удаленного MinIO (для бэкапов).                                       | `number`  |
| `local_backup_minio_port`  | Порт для локального MinIO (для бэкапов в режиме `local_storage`).               | `number`  |
| `storage_type`             | Тип хранилища: `local_ssd`, `s3_ssd` или `local_storage`.                     | `string`  |
| `local_minio_path`         | Путь к данным для локального MinIO (`s3_ssd`).                                | `string`  |
| `remote_minio_path`        | Путь к данным для удаленного MinIO.                                            | `string`  |
| `local_backup_minio_path`  | Путь к данным для локального MinIO (бэкап).                                    | `string`  |
| `remote_host_name`         | Имя хоста для удаленного MinIO.                                                | `string`  |
| `bucket_backup`            | Имя бакета для бэкапов.                                                        | `string`  |
| `bucket_storage`           | Имя бакета для S3 хранилища.                                                   | `string`  |

## Выходные данные (Outputs)

| Имя                    | Описание                                                                        |
|------------------------|---------------------------------------------------------------------------------|
| `deployment_summary`   | Сводная информация о развернутой конфигурации и эндпоинтах.                     |
| `clickhouse_nodes_info`| Детальная информация о каждой ноде ClickHouse (шард, реплика, порты).          |
| `keeper_nodes_info`    | Детальная информация о каждой ноде ClickHouse Keeper.                          |
| `network_name`         | Имя созданной Docker-сети.                                                     |
