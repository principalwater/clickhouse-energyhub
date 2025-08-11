# Terraform Module: Monitoring (Portainer)

Этот модуль Terraform разворачивает Portainer Community Edition — легковесный и мощный инструмент для управления и мониторинга Docker-контейнеров.

## Архитектура

Модуль создает следующие компоненты:
- **Portainer Container:** Один контейнер `portainer/portainer-ce`, который предоставляет веб-интерфейс для управления Docker.
- **Persistent Volume:** `docker_volume` для хранения данных и конфигурации Portainer, что обеспечивает их сохранность между перезапусками.
- **Docker Socket Access:** Модуль монтирует сокет Docker (`/var/run/docker.sock`) в контейнер, предоставляя Portainer полный доступ для управления другими контейнерами на хосте.

## Входные переменные (Input Variables)

| Имя | Описание |
| --- | --- |
| `portainer_version` | Версия Portainer CE (например, `latest` или `2.19.4`). |
| `portainer_https_port`| Порт для доступа к веб-интерфейсу Portainer по HTTPS. |
| `portainer_agent_port`| Порт, используемый для подключения к Docker agent. |

## Доступ к сервису

После успешного выполнения `terraform apply`:

- **Portainer UI:**
  - **URL:** `https://localhost:<portainer_https_port>` (по умолчанию `9443`).
  - **Первый вход:** При первом входе Portainer попросит вас создать пароль для пользователя `admin`.
