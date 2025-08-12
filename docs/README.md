# 📚 Документация ClickHouse EnergyHub

Добро пожаловать в документацию проекта ClickHouse EnergyHub! Здесь вы найдете подробные руководства, архитектурные решения и практические примеры.

## 🗂️ Структура документации

### 🚀 Быстрый старт

- **[QUICK_START.md](QUICK_START.md)** - Полный туториал по развертыванию за 15 минут
  - Пошаговые инструкции
  - Проверка предварительных требований
  - Устранение неполадок
  - Проверка работоспособности

### 🏗️ Архитектура и дизайн

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Подробная архитектура Data Warehouse
  - Слои данных (RAW, ODS, DDS, CDM)
  - Нейминг конвенции
  - Модели данных
  - Технологический стек
  - Планы развития

### 🔗 Интеграции и инструменты

- **[DBT_INTEGRATION.md](DBT_INTEGRATION.md)** - Полное руководство по dbt
  - Конфигурация проекта
  - Модели данных
  - Тестирование
  - Макросы
  - Оптимизация производительности

### 🚀 Автоматизация и DevOps

- **[CI_CD.md](CI_CD.md)** - CI/CD пайплайн и автоматизация
  - GitHub Actions workflows
  - Автоматизированное тестирование
  - Безопасность и сканирование
  - Стратегии развертывания
  - Мониторинг и алерты

### 🔄 Специализированные DAG'и

- **[README_deduplication.md](README_deduplication.md)** - DAG для автоматической дедупликации
  - Автоматическое обновление dbt sources
  - Система очистки дублей
  - Мониторинг и логирование
  - Устранение неполадок

- **[README_clickhouse_backup.md](README_clickhouse_backup.md)** - DAG для резервного копирования
  - Создание и верификация бэкапов
  - Умное восстановление
  - Очистка старых бэкапов
  - Мониторинг здоровья системы

## 🎯 Как использовать документацию

### 👶 Для новичков

1. **Начните с [QUICK_START.md](QUICK_START.md)** - разверните систему за 15 минут
2. **Изучите [ARCHITECTURE.md](ARCHITECTURE.md)** - поймите общую структуру
3. **Перейдите к [DBT_INTEGRATION.md](DBT_INTEGRATION.md)** - изучите работу с данными

### 🔧 Для разработчиков

1. **Изучите [CI_CD.md](CI_CD.md)** - настройте автоматизацию
2. **Изучите специализированные DAG'и** - поймите логику автоматизации
3. **Используйте примеры кода** из всех документов

### 🏗️ Для архитекторов

1. **Изучите [ARCHITECTURE.md](ARCHITECTURE.md)** - поймите принципы проектирования
2. **Изучите [DBT_INTEGRATION.md](DBT_INTEGRATION.md)** - поймите подход к трансформации данных
3. **Изучите [CI_CD.md](CI_CD.md)** - поймите подход к автоматизации

## 🔍 Поиск по документации

### По технологиям

- **ClickHouse** → [ARCHITECTURE.md](ARCHITECTURE.md), [DBT_INTEGRATION.md](DBT_INTEGRATION.md)
- **dbt** → [DBT_INTEGRATION.md](DBT_INTEGRATION.md), [README_deduplication.md](README_deduplication.md)
- **Airflow** → [README_deduplication.md](README_deduplication.md), [README_clickhouse_backup.md](README_clickhouse_backup.md)
- **Terraform** → [CI_CD.md](CI_CD.md), [QUICK_START.md](QUICK_START.md)

### По задачам

- **Развертывание** → [QUICK_START.md](QUICK_START.md)
- **Разработка** → [DBT_INTEGRATION.md](DBT_INTEGRATION.md), [CI_CD.md](CI_CD.md)
- **Мониторинг** → [README_deduplication.md](README_deduplication.md), [README_clickhouse_backup.md](README_clickhouse_backup.md)
- **Устранение неполадок** → Все документы содержат разделы troubleshooting

## 📖 Примеры использования

### 🚀 Быстрое развертывание

```bash
# Клонирование и развертывание
git clone https://github.com/your-username/clickhouse-energyhub.git
cd clickhouse-energyhub
./deploy.sh
```

### 🧹 Запуск дедупликации

```bash
# Ручной запуск DAG
docker exec airflow-scheduler airflow dags trigger deduplication_pipeline
```

### 🔍 Проверка данных

```bash
# Проверка таблиц в ClickHouse
docker exec clickhouse-01 clickhouse-client --query "
SELECT name FROM system.tables WHERE database = 'dds' ORDER BY name
"
```

## 🔄 Обновление документации

### 📝 Внесение изменений

1. **Создайте issue** с описанием необходимых изменений
2. **Создайте branch** для работы над документацией
3. **Внесите изменения** в соответствующие файлы
4. **Создайте Pull Request** с описанием изменений

### 📋 Стандарты документации

- **Markdown формат** для всех документов
- **Emoji** для улучшения читаемости
- **Примеры кода** для практического применения
- **Ссылки между документами** для навигации
- **Структурированные разделы** для легкого поиска

## 🆘 Получение помощи

### 📚 Дополнительные ресурсы

- **GitHub Wiki** - [Wiki проекта](https://github.com/your-username/clickhouse-energyhub/wiki)
- **GitHub Issues** - [Вопросы и проблемы](https://github.com/your-username/clickhouse-energyhub/issues)
- **GitHub Discussions** - [Обсуждения и идеи](https://github.com/your-username/clickhouse-energyhub/discussions)

### 📧 Контакты

- **Email:** support@energyhub.com
- **Slack:** [#energyhub](https://slack.com/app_redirect?channel=energyhub)
- **Discord:** [EnergyHub Community](https://discord.gg/energyhub)

## 📈 Статистика документации

- **Общее количество документов:** 6
- **Общий объем:** ~50,000 слов
- **Примеры кода:** 100+
- **Диаграммы и схемы:** 20+
- **Последнее обновление:** 2025-08-12

---

**💡 Совет:** Используйте поиск по ключевым словам в вашем редакторе для быстрого нахождения нужной информации!

**🚀 Удачи в изучении ClickHouse EnergyHub!**
