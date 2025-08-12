# Настройка подключения к ClickHouse в BI-инструментах

Данное руководство описывает, как настроить подключение к ClickHouse в Metabase и Apache Superset после развертывания инфраструктуры.

## Обзор

После развертывания инфраструктуры через Terraform:
- ✅ ClickHouse кластер работает на `localhost:8123` (HTTP) и `localhost:9000` (TCP)
- ✅ Metabase v0.55.12 доступен на `http://localhost:3000` (ClickHouse встроен в ядро)
- ✅ Apache Superset доступен на `http://localhost:8088` с установленными ClickHouse драйверами
- ⚠️ Подключения к ClickHouse настраиваются **вручную** через веб-интерфейс

## Данные для подключения

### 🔑 Получение креденшиалов

Все необходимые учетные данные находятся в файле `infra/terraform/Terraform.tfvars`:

```bash
# Для BI подключений к ClickHouse
bi_user_password = "ваш_пароль_здесь"

# Для входа в Metabase и Superset
sa_username = "ваш_admin_логин"
sa_password = "ваш_admin_пароль"
```

### 📋 Параметры подключения

Используйте следующие параметры для подключения к ClickHouse:

| Параметр | Значение |
|----------|----------|
| **Host** | `host.docker.internal` |
| **Port** | `8123` (HTTP) |
| **Database** | `raw` |
| **Username** | `bi_user` |
| **Password** | `<значение_bi_user_password_из_tfvars>` |
| **SSL** | `false` |

> **Важно**: Используется `host.docker.internal` вместо `localhost` или `clickhouse-01`, так как BI-инструменты работают в Docker контейнерах.

---

## 🔹 Настройка Metabase

### Шаг 1: Войти в Metabase Admin Panel

1. Откройте браузер и перейдите на `http://localhost:3000`
2. Войдите в систему:
   - **Email**: `<значение_sa_username_из_tfvars>@local.com`
   - **Password**: `<значение_sa_password_из_tfvars>`
3. Нажмите на иконку шестеренки (⚙️) в правом верхнем углу
4. Выберите **"Admin Settings"**

### Шаг 2: Добавить базу данных

1. В панели администратора нажмите **"Databases"** в левом меню
2. Нажмите кнопку **"Add database"**
3. В выпадающем списке **"Database type"** выберите **"ClickHouse"**
   
   > ✅ **ClickHouse встроен в Metabase v0.55.12+** - отдельный плагин больше не нужен!

### Шаг 3: Настроить подключение

Заполните форму подключения:

| Поле | Значение |
|------|----------|
| **Display name** | `ClickHouse EnergyHub` |
| **Host** | `host.docker.internal` |
| **Port** | `8123` |
| **Database name** | `raw` |
| **Username** | `bi_user` |
| **Password** | `<значение_bi_user_password_из_tfvars>` |
| **Use a secure connection (SSL)** | ❌ (отключено) |

### Шаг 4: Сохранить и проверить

1. Нажмите **"Save"**
2. Metabase автоматически проверит подключение
3. При успешном подключении вы увидите сообщение ✅ **"Successfully connected to ClickHouse EnergyHub"**
4. Metabase начнет сканирование таблиц в базе данных

### Шаг 5: Начать работу с данными

1. Нажмите **"Exit admin"** в правом верхнем углу
2. На главной странице нажмите **"+ New"** → **"Question"**
3. Выберите **"ClickHouse EnergyHub"** как источник данных
4. Выберите таблицу и начните создавать запросы

---

## 🔸 Настройка Apache Superset

### Шаг 1: Войти в Superset

1. Откройте браузер и перейдите на `http://localhost:8088`
2. Войдите в систему:
   - **Username**: `<значение_sa_username_из_tfvars>`
   - **Password**: `<значение_sa_password_из_tfvars>`

### Шаг 2: Добавить базу данных

1. В верхнем меню нажмите **"Settings"** → **"Database Connections"**
2. Нажмите кнопку **"+ DATABASE"**
3. В разделе **"SUPPORTED DATABASES"** найдите и выберите **"ClickHouse"**

### Шаг 3: Настроить подключение

#### Вкладка "Basic"

| Поле | Значение |
|------|----------|
| **Database name** | `ClickHouse EnergyHub` |
| **SQLAlchemy URI** | `clickhousedb://bi_user:<значение_bi_user_password_из_tfvars>@host.docker.internal:8123/raw` |

#### Вкладка "Advanced" (опционально)

В поле **"Extra"** можно добавить дополнительные параметры:
```json
{
  "metadata_params": {},
  "engine_params": {
    "connect_args": {
      "interface": "http"
    }
  },
  "metadata_cache_timeout": {},
  "schemas_allowed_for_csv_upload": []
}
```

### Шаг 4: Проверить подключение

1. Нажмите **"Test Connection"**
2. При успешном подключении появится сообщение ✅ **"Connection looks good!"**
3. Нажмите **"Connect"** для сохранения

### Шаг 5: Начать работу с данными

1. В верхнем меню нажмите **"SQL"** → **"SQL Lab"**
2. В выпадающем списке **"Database"** выберите **"ClickHouse EnergyHub"**
3. В поле **"Schema"** выберите `raw`
4. Начните писать SQL запросы к данным ClickHouse

---

## 🔧 Диагностика проблем

### Проблема: ClickHouse не появляется в списке типов БД в Metabase

**Решение**:
1. **Для Metabase v0.55.12+**: ClickHouse встроен в ядро, никаких дополнительных плагинов не требуется.
2. Убедитесь, что используется Metabase v0.54+ - предыдущие версии требуют отдельный плагин.
3. Перезапустите Metabase, если проблема сохраняется:
   ```bash
   docker restart metabase
   ```
3. Проверьте логи на ошибки:
   ```bash
   docker logs metabase | grep -i "clickhouse\|error\|plugin"
   ```

### Проблема: Ошибка подключения "Could not resolve host"

**Решение**:
- Убедитесь, что используете `host.docker.internal` вместо `localhost` или `clickhouse-01`
- Проверьте, что ClickHouse доступен:
  ```bash
  docker exec metabase curl -I http://host.docker.internal:8123/
  docker exec superset curl -I http://host.docker.internal:8123/
  ```

### Проблема: ClickHouse драйверы не установлены в Superset

**Решение**:
1. Проверьте установленные пакеты:
   ```bash
   docker exec superset pip list | grep -i click
   ```
2. Если драйверы отсутствуют, установите их вручную:
   ```bash
   docker exec superset pip install clickhouse-connect>=0.6.8 clickhouse-driver
   docker restart superset
   ```

### Проблема: Таблицы не отображаются в BI-инструментах

**Решение**:
1. Проверьте, что таблицы существуют в ClickHouse:
   ```bash
   docker exec clickhouse-01 clickhouse-client --query "SHOW TABLES FROM raw"
   ```
2. Убедитесь, что у пользователя `bi_user` есть права доступа:
   ```bash
   docker exec clickhouse-01 clickhouse-client --query "SHOW GRANTS FOR bi_user"
   ```

---

## 📊 Примеры использования

### Metabase: Создание простого графика

1. **Новый вопрос** → **Простой режим**
2. Выберите таблицу (например, `raw.energy_data_1min`)
3. Выберите метрику для отображения
4. Примените фильтры по дате
5. Выберите тип визуализации (линейный график, столбчатая диаграмма, и т.д.)

### Superset: SQL запрос

```sql
SELECT 
    toDate(timestamp) as date,
    avg(power_kwh) as avg_power
FROM raw.energy_data_1min 
WHERE timestamp >= today() - 7
GROUP BY date
ORDER BY date
```

### Полезные таблицы для анализа

После развертывания в ClickHouse доступны следующие таблицы:

| Таблица | Описание |
|---------|----------|
| `raw.energy_data_1min` | Данные энергопотребления по минутам |
| `raw.energy_data_5min` | Агрегированные данные по 5 минут |
| `raw.market_data` | Рыночные данные Nord Pool |
| `raw.river_flow_data` | Данные о расходе воды в реках |
| `raw.weather_data` | Метеорологические данные |

---

## 🔗 Полезные ссылки

- [Официальная документация ClickHouse для Metabase](https://clickhouse.com/docs/integrations/metabase)
- [Настройка Superset с ClickHouse](https://superset.apache.org/docs/configuration/databases#clickhouse)
- [ClickHouse SQL синтаксис](https://clickhouse.com/docs/sql-reference/)
- [Metabase пользовательское руководство](https://www.metabase.com/docs/)
- [Apache Superset документация](https://superset.apache.org/docs/intro)

---

## 📝 Примечания

- **Безопасность**: В продакшен среде обязательно смените пароли и настройте SSL
- **Производительность**: Для больших датасетов рассмотрите создание материализованных представлений в ClickHouse
- **Мониторинг**: Настройте мониторинг производительности запросов через ClickHouse system tables
- **Бэкапы**: Регулярно создавайте резервные копии конфигураций BI-инструментов

> **Обратная связь**: Если у вас возникли проблемы с настройкой, проверьте логи контейнеров и убедитесь, что все сервисы запущены и здоровы.
