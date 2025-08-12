# 🚀 CI/CD Pipeline

## Обзор

ClickHouse EnergyHub использует современные практики **Continuous Integration** и **Continuous Deployment** для автоматизации разработки, тестирования и развертывания. Это обеспечивает высокое качество кода, быструю доставку изменений и надежность системы.

## 🏗️ Архитектура CI/CD

### Общая архитектура CI/CD Pipeline

```mermaid
graph TB
    %% Разработчик
    subgraph "👨‍💻 Development"
        principalwater[Vladislav Kuzmin<br/>Developer<br/>All Features & Infrastructure]
    end
    
    %% GitHub Repository
    subgraph "📚 GitHub Repository"
        MASTER[master branch<br/>Production Ready<br/>Default Branch]
        BI_INFRA[bi-infra branch<br/>BI Infrastructure<br/>Superset, Metabase]
        KAFKA_INFRA[kafka-infra branch<br/>Kafka Infrastructure<br/>SSL, SASL, ACL]
        AIRFLOW_INFRA[airflow-infra branch<br/>Airflow Infrastructure<br/>3.0.4, Celery]
        DBT_INFRA[dbt-infra branch<br/>dbt Infrastructure<br/>Models, Tests]
        DATA_INFRA[data-infra branch<br/>Data Infrastructure<br/>ClickHouse, PostgreSQL]
        ADDITIONAL_INFRA[additional-infra branch<br/>Additional Services<br/>Monitoring, Backup]
    end
    
    %% GitHub Actions
    subgraph "🔄 GitHub Actions CI/CD"
        subgraph "CI Pipeline (ci.yml)"
            CHECKOUT[Checkout Code]
            TERRAFORM_SETUP[Setup Terraform 1.7.5]
            TERRAFORM_VALIDATE[Terraform Validate<br/>Format Check]
            TERRAFORM_PLAN[Terraform Plan<br/>Infrastructure Changes]
            PYTHON_LINT[Python Syntax Check<br/>Shell Script Validation]
            DBT_CHECK[dbt Project Validation<br/>Model Structure Check]
        end
        
        subgraph "Auto Approve (approve.yml)"
            BOT_COMMENT[Elementary Flow Bot<br/>Comment: /approve]
            AUTO_APPROVE[Auto Approve PR<br/>Using Bot PAT]
        end
    end
    
    %% Инфраструктура
    subgraph "🏗️ Infrastructure (Terraform)"
        subgraph "ClickHouse Cluster"
            CH_CLUSTER[4 Nodes + 3 Keeper<br/>ReplicatedMergeTree<br/>Distributed Tables]
        end
        
        subgraph "Data Processing"
            AIRFLOW[Apache Airflow 3.0.4<br/>Celery Workers<br/>PostgreSQL Backend]
            DBT[dbt Core + ClickHouse<br/>4 Data Layers<br/>RAW, ODS, DDS, CDM]
            KAFKA[Apache Kafka<br/>SSL + SASL<br/>2 Topics]
        end
        
        subgraph "BI & Monitoring"
            SUPERSET[Apache Superset<br/>Analytics Dashboards]
            METABASE[Metabase<br/>Self-Service BI]
            POSTGRES[PostgreSQL<br/>Centralized DB]
            PORTAINER[Portainer<br/>Container Management]
        end
    end
    
    %% Потоки разработки
    principalwater --> BI_INFRA
    principalwater --> KAFKA_INFRA
    principalwater --> AIRFLOW_INFRA
    principalwater --> DBT_INFRA
    principalwater --> DATA_INFRA
    principalwater --> ADDITIONAL_INFRA
    
    BI_INFRA --> MASTER
    KAFKA_INFRA --> MASTER
    AIRFLOW_INFRA --> MASTER
    DBT_INFRA --> MASTER
    DATA_INFRA --> MASTER
    ADDITIONAL_INFRA --> MASTER
    
    %% CI/CD потоки
    BI_INFRA --> CHECKOUT
    KAFKA_INFRA --> CHECKOUT
    AIRFLOW_INFRA --> CHECKOUT
    DBT_INFRA --> CHECKOUT
    DATA_INFRA --> CHECKOUT
    ADDITIONAL_INFRA --> CHECKOUT
    
    CHECKOUT --> TERRAFORM_SETUP
    TERRAFORM_SETUP --> TERRAFORM_VALIDATE
    TERRAFORM_VALIDATE --> TERRAFORM_PLAN
    TERRAFORM_PLAN --> PYTHON_LINT
    PYTHON_LINT --> DBT_CHECK
    
    %% Auto Approve
    principalwater --> BOT_COMMENT
    BOT_COMMENT --> AUTO_APPROVE
    AUTO_APPROVE --> MASTER
    
    %% Инфраструктура
    TERRAFORM_PLAN --> CH_CLUSTER
    TERRAFORM_PLAN --> AIRFLOW
    TERRAFORM_PLAN --> DBT
    TERRAFORM_PLAN --> KAFKA
    TERRAFORM_PLAN --> SUPERSET
    TERRAFORM_PLAN --> METABASE
    TERRAFORM_PLAN --> POSTGRES
    TERRAFORM_PLAN --> PORTAINER
    
    %% Стили
    classDef dev fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef github fill:#fce4ec,stroke:#c2185b,stroke-width:2px
    classDef ci fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    classDef infra fill:#e8f5e8,stroke:#388e3c,stroke-width:2px
    classDef bot fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    
    class principalwater dev
    class MASTER,BI_INFRA,KAFKA_INFRA,AIRFLOW_INFRA,DBT_INFRA,DATA_INFRA,ADDITIONAL_INFRA github
    class CHECKOUT,TERRAFORM_SETUP,TERRAFORM_VALIDATE,TERRAFORM_PLAN,PYTHON_LINT,DBT_CHECK ci
    class BOT_COMMENT,AUTO_APPROVE bot
    class CH_CLUSTER,AIRFLOW,DBT,KAFKA,SUPERSET,METABASE,POSTGRES,PORTAINER infra
```

### Детальный поток CI/CD процессов

```mermaid
flowchart TD
    %% Триггеры
    subgraph "🚀 Triggers"
        PUSH[Push to master]
        PR[Pull Request<br/>from feature branches]
        MANUAL[Manual Trigger<br/>workflow_dispatch]
    end
    
    %% CI этапы (ci.yml)
    subgraph "🧪 Continuous Integration"
        subgraph "Terraform Validation"
            TERRAFORM_INIT[Terraform Init<br/>Backend=false]
            TERRAFORM_VALIDATE[Terraform Validate<br/>Syntax & Logic]
            TERRAFORM_FMT[Terraform Format Check<br/>fmt -check]
            TERRAFORM_PLAN[Terraform Plan<br/>Infrastructure Changes<br/>+ Artifact Upload]
        end
        
        subgraph "Code Quality"
            PYTHON_SYNTAX[Python Syntax Check<br/>py_compile all .py files]
            SHELL_SYNTAX[Shell Script Validation<br/>bash -n all .sh files]
        end
        
        subgraph "dbt Validation"
            DBT_SETUP[dbt Setup<br/>dbt-core + dbt-clickhouse]
            DBT_STRUCTURE[dbt Project Structure<br/>Validate layers: RAW, ODS, DDS, CDM]
            DBT_PARSE[dbt Parse<br/>Syntax validation<br/>Offline mode]
            DBT_MODELS[dbt Model Validation<br/>List models by tags]
        end
    end
    
    %% Auto Approve (approve.yml)
    subgraph "🤖 Auto Approval"
        BOT_TRIGGER[Elementary Flow Bot<br/>Comment: /approve]
        BOT_CHECK[Check Conditions<br/>• PR exists<br/>• Comment = /approve<br/>• Author = principalwater]
        AUTO_APPROVE[Auto Approve PR<br/>Using ELEMENTARY_FLOW_BOT_PAT]
    end
    
    %% Развертывание
    subgraph "🚀 Deployment"
        MERGE[Merge to master<br/>After approval]
        TERRAFORM_APPLY[Terraform Apply<br/>Infrastructure deployment]
        HEALTH_CHECK[Health Checks<br/>All services status]
    end
    
    %% Потоки
    PUSH --> TERRAFORM_INIT
    PR --> TERRAFORM_INIT
    MANUAL --> TERRAFORM_INIT
    
    TERRAFORM_INIT --> TERRAFORM_VALIDATE
    TERRAFORM_VALIDATE --> TERRAFORM_FMT
    TERRAFORM_FMT --> TERRAFORM_PLAN
    
    TERRAFORM_PLAN --> PYTHON_SYNTAX
    PYTHON_SYNTAX --> SHELL_SYNTAX
    
    SHELL_SYNTAX --> DBT_SETUP
    DBT_SETUP --> DBT_STRUCTURE
    DBT_STRUCTURE --> DBT_PARSE
    DBT_PARSE --> DBT_MODELS
    
    %% Auto Approve flow
    PR --> BOT_TRIGGER
    BOT_TRIGGER --> BOT_CHECK
    BOT_CHECK --> AUTO_APPROVE
    
    AUTO_APPROVE --> MERGE
    MERGE --> TERRAFORM_APPLY
    TERRAFORM_APPLY --> HEALTH_CHECK
    
    %% Стили
    classDef trigger fill:#e1f5fe,stroke:#0277bd,stroke-width:2px
    classDef ci fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    classDef bot fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    classDef deploy fill:#e8f5e8,stroke:#388e3c,stroke-width:2px
    
    class PUSH,PR,MANUAL trigger
    class TERRAFORM_INIT,TERRAFORM_VALIDATE,TERRAFORM_FMT,TERRAFORM_PLAN,PYTHON_SYNTAX,SHELL_SYNTAX,DBT_SETUP,DBT_STRUCTURE,DBT_PARSE,DBT_MODELS ci
    class BOT_TRIGGER,BOT_CHECK,AUTO_APPROVE bot
    class MERGE,TERRAFORM_APPLY,HEALTH_CHECK deploy
```

### Автоматизация и качество

**Quality Gates:**
- ✅ Terraform validation passed
- ✅ Python syntax check passed
- ✅ Shell script validation passed
- ✅ dbt project structure valid
- ✅ dbt models syntax valid

**🤖 Elementary Flow Bot**
Для автоматизации процесса одобрения Pull Request используется **Elementary Flow Bot** ([@elementary-flow-bot](https://github.com/elementary-flow-bot)), разработанный и подключенный к репозиторию. Бот автоматически одобряет PR при выполнении следующих условий:

- Комментарий `/approve` оставлен в Pull Request
- Автор комментария - `principalwater` (создатель репозитория)
- PR существует и готов к слиянию

**Процесс автоматического одобрения:**
1. Создание Pull Request из feature branch в master
2. Прохождение всех CI проверок (Terraform, Python, dbt)
3. Комментарий `/approve` от principalwater
4. Автоматическое одобрение Elementary Flow Bot
5. Слияние в master branch
6. Автоматическое развертывание инфраструктуры

## 🔄 Workflow GitHub Actions

### Основной CI/CD Pipeline

```yaml
# .github/workflows/main.yml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]
  release:
    types: [ published ]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  # Тестирование
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
          
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt
          pip install -r requirements-dev.txt
          
      - name: Run linting
        run: |
          flake8 .
          black --check .
          isort --check-only .
          
      - name: Run tests
        run: |
          pytest tests/ --cov=. --cov-report=xml
          
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage.xml

  # Безопасность
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run security scan
        uses: github/codeql-action/init@v2
        with:
          languages: python, yaml, dockerfile
          
      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v2
        
      - name: Run dependency check
        run: |
          pip install safety
          safety check

  # Сборка и публикация
  build-and-push:
    needs: [test, security]
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
        
      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
          
      - name: Build and push Docker image
        uses: docker/build-push-action@v4
        with:
          context: .
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  # Развертывание
  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: '1.5.0'
          
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}
          
      - name: Terraform Init
        run: |
          cd infra/terraform
          terraform init
          
      - name: Terraform Plan
        run: |
          cd infra/terraform
          terraform plan -out=tfplan
          
      - name: Terraform Apply
        run: |
          cd infra/terraform
          terraform apply tfplan
```

### Pull Request Pipeline

```yaml
# .github/workflows/pr.yml
name: Pull Request Checks

on:
  pull_request:
    branches: [ main, develop ]

jobs:
  pr-checks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Check formatting
        run: |
          python -m pip install black isort
          black --check .
          isort --check-only .
          
      - name: Run linter
        run: |
          python -m pip install flake8
          flake8 . --max-line-length=88
          
      - name: Check Terraform
        run: |
          cd infra/terraform
          terraform init
          terraform validate
          terraform fmt -check
          
      - name: Check dbt
        run: |
          cd dbt
          dbt debug
          dbt compile
```

## 🧪 Автоматизированное тестирование

### Типы тестов

#### 1. **Unit Tests** (Модульные тесты)
```python
# tests/test_clickhouse_backup_manager.py
import pytest
from scripts.clickhouse_backup_manager import ClickHouseBackupManager

class TestClickHouseBackupManager:
    def test_get_latest_backup(self):
        manager = ClickHouseBackupManager()
        latest = manager.get_latest_backup()
        assert latest is not None
        assert isinstance(latest, str)
    
    def test_create_backup(self):
        manager = ClickHouseBackupManager()
        result = manager.create_backup()
        assert result is not None
        assert "Backup created" in result
```

#### 2. **Integration Tests** (Интеграционные тесты)
```python
# tests/test_dbt_integration.py
import pytest
from dbt.cli.main import dbtRunner

class TestDbtIntegration:
    def test_dbt_compile(self):
        dbt = dbtRunner()
        result = dbt.invoke(["compile"])
        assert result.success
        
    def test_dbt_run(self):
        dbt = dbtRunner()
        result = dbt.invoke(["run", "--select", "tag:test"])
        assert result.success
```

#### 3. **End-to-End Tests** (Сквозные тесты)
```python
# tests/test_full_pipeline.py
import pytest
import docker

class TestFullPipeline:
    def test_airflow_dag_loading(self):
        client = docker.from_env()
        container = client.containers.get("airflow-scheduler")
        
        result = container.exec_run("python -c 'from deduplication_pipeline import deduplication_dag; print(\"DAG loaded\")'")
        assert result.exit_code == 0
        assert "DAG loaded" in result.output.decode()
```

### Конфигурация pytest

```ini
# pytest.ini
[tool:pytest]
testpaths = tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*
addopts = 
    --verbose
    --tb=short
    --strict-markers
    --disable-warnings
    --cov=.
    --cov-report=html
    --cov-report=term-missing
markers =
    unit: Unit tests
    integration: Integration tests
    e2e: End-to-end tests
    slow: Slow running tests
```

## 🔒 Безопасность

### Сканирование безопасности

#### 1. **CodeQL Analysis**
```yaml
# .github/workflows/codeql.yml
name: "CodeQL"

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  schedule:
    - cron: '30 1 * * 0'

jobs:
  analyze:
    runs-on: ubuntu-latest
    permissions:
      actions: read
      contents: read
      security-events: write
    
    strategy:
      fail-fast: false
      matrix:
        language: [ 'python', 'yaml', 'dockerfile' ]
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Initialize CodeQL
        uses: github/codeql-action/init@v2
        with:
          languages: ${{ matrix.language }}
          
      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v2
```

#### 2. **Dependency Scanning**
```yaml
# .github/workflows/dependency-check.yml
name: Dependency Check

on:
  schedule:
    - cron: '0 2 * * 1'  # Каждый понедельник в 2:00
  workflow_dispatch:

jobs:
  dependency-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run Safety Check
        run: |
          pip install safety
          safety check --output json > safety-report.json
          
      - name: Upload Safety Report
        uses: actions/upload-artifact@v3
        with:
          name: safety-report
          path: safety-report.json
```

#### 3. **Container Security**
```yaml
# .github/workflows/container-scan.yml
name: Container Security Scan

on:
  push:
    branches: [ main ]
    paths: [ 'Dockerfile*', 'docker-compose*' ]

jobs:
  container-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest
          format: 'sarif'
          output: 'trivy-results.sarif'
          
      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'
```

## 🚀 Автоматизация развертывания

### Terraform Automation

#### 1. **Infrastructure as Code**
```hcl
# infra/terraform/main.tf
terraform {
  required_version = ">= 1.0"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket = "clickhouse-energyhub-terraform"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }
}

# Автоматическое создание ресурсов
resource "docker_network" "clickhouse_network" {
  name = "clickhouse-network"
}

resource "docker_container" "clickhouse_01" {
  name  = "clickhouse-01"
  image = docker_image.clickhouse.latest
  
  networks_advanced {
    name = docker_network.clickhouse_network.name
  }
  
  env = [
    "CLICKHOUSE_DB=default",
    "CLICKHOUSE_USER=${var.clickhouse_user}",
    "CLICKHOUSE_PASSWORD=${var.clickhouse_password}"
  ]
}
```

#### 2. **Environment Management**
```hcl
# infra/terraform/environments/prod.tfvars
environment = "production"
clickhouse_cluster_size = 4
airflow_workers = 3
monitoring_enabled = true
backup_retention_days = 30

# Автоматическое масштабирование
autoscaling = {
  min_instances = 2
  max_instances = 10
  target_cpu_utilization = 70
}
```

### Deployment Strategies

#### 1. **Blue-Green Deployment**
```yaml
# .github/workflows/blue-green-deploy.yml
name: Blue-Green Deployment

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy to'
        required: true
        default: 'staging'
        type: choice
        options:
          - staging
          - production

jobs:
  blue-green-deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy Blue Environment
        run: |
          echo "Deploying to Blue environment..."
          # Логика развертывания Blue
          
      - name: Run Smoke Tests
        run: |
          echo "Running smoke tests..."
          # Тесты работоспособности
          
      - name: Switch Traffic to Blue
        run: |
          echo "Switching traffic to Blue..."
          # Переключение трафика
          
      - name: Decommission Green Environment
        run: |
          echo "Decommissioning Green environment..."
          # Очистка старой среды
```

#### 2. **Rolling Update**
```yaml
# .github/workflows/rolling-update.yml
name: Rolling Update

on:
  workflow_dispatch:

jobs:
  rolling-update:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node: [1, 2, 3, 4]
        
    steps:
      - name: Update Node ${{ matrix.node }}
        run: |
          echo "Updating ClickHouse node ${{ matrix.node }}..."
          # Логика обновления узла
          
      - name: Wait for Node Health
        run: |
          echo "Waiting for node health check..."
          # Проверка здоровья узла
          
      - name: Verify Cluster Health
        run: |
          echo "Verifying cluster health..."
          # Проверка здоровья кластера
```

## 📊 Мониторинг и алерты

### Health Checks

#### 1. **Service Health Monitoring**
```yaml
# .github/workflows/health-check.yml
name: Health Check

on:
  schedule:
    - cron: '*/5 * * * *'  # Каждые 5 минут

jobs:
  health-check:
    runs-on: ubuntu-latest
    steps:
      - name: Check ClickHouse Health
        run: |
          docker exec clickhouse-01 clickhouse-client --query "SELECT 1"
          
      - name: Check Airflow Health
        run: |
          curl -f http://localhost:8080/health
          
      - name: Check dbt Models
        run: |
          cd dbt
          dbt test --select tag:critical
          
      - name: Send Alert on Failure
        if: failure()
        run: |
          echo "Health check failed!"
          # Отправка алерта
```

#### 2. **Performance Monitoring**
```yaml
# .github/workflows/performance-check.yml
name: Performance Check

on:
  schedule:
    - cron: '0 */6 * * *'  # Каждые 6 часов

jobs:
  performance-check:
    runs-on: ubuntu-latest
    steps:
      - name: Check Query Performance
        run: |
          docker exec clickhouse-01 clickhouse-client --query "
            SELECT 
              query,
              query_duration_ms,
              memory_usage
            FROM system.query_log
            WHERE type = 'QueryFinish'
            AND query_duration_ms > 10000
            ORDER BY query_duration_ms DESC
            LIMIT 10
          "
          
      - name: Check Storage Usage
        run: |
          docker exec clickhouse-01 clickhouse-client --query "
            SELECT 
              database,
              table,
              formatReadableSize(total_bytes) as size
            FROM system.tables
            ORDER BY total_bytes DESC
            LIMIT 20
          "
```

### Alerting

#### 1. **Slack Notifications**
```yaml
# .github/workflows/notify-slack.yml
name: Notify Slack

on:
  workflow_run:
    workflows: ["CI/CD Pipeline"]
    types:
      - completed
      - failure

jobs:
  notify:
    runs-on: ubuntu-latest
    if: always()
    steps:
      - name: Notify Slack
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          channel: '#deployments'
          webhook_url: ${{ secrets.SLACK_WEBHOOK_URL }}
```

#### 2. **Email Notifications**
```yaml
# .github/workflows/notify-email.yml
name: Notify Email

on:
  workflow_run:
    workflows: ["Health Check"]
    types:
      - failure

jobs:
  notify-email:
    runs-on: ubuntu-latest
    steps:
      - name: Send Email Alert
        run: |
          echo "Health check failed at $(date)" | mail -s "Alert: Health Check Failed" admin@company.com
```

## 🔄 Rollback Strategy

### Автоматический Rollback

```yaml
# .github/workflows/auto-rollback.yml
name: Auto Rollback

on:
  workflow_run:
    workflows: ["Deploy"]
    types:
      - failure

jobs:
  rollback:
    runs-on: ubuntu-latest
    steps:
      - name: Check Previous Deployment
        run: |
          echo "Checking previous deployment..."
          
      - name: Rollback to Previous Version
        run: |
          echo "Rolling back to previous version..."
          # Логика отката
          
      - name: Verify Rollback
        run: |
          echo "Verifying rollback..."
          # Проверка отката
          
      - name: Notify Team
        run: |
          echo "Rollback completed and verified"
          # Уведомление команды
```

### Manual Rollback

```bash
#!/bin/bash
# scripts/rollback.sh

set -e

echo "🚨 Starting manual rollback..."

# Получаем предыдущую версию
PREVIOUS_VERSION=$(git log --oneline -n 2 | tail -1 | awk '{print $1}')

echo "📋 Rolling back to version: $PREVIOUS_VERSION"

# Откатываемся к предыдущей версии
git checkout $PREVIOUS_VERSION

# Перезапускаем инфраструктуру
cd infra/terraform
terraform apply -var="version=$PREVIOUS_VERSION"

echo "✅ Rollback completed successfully!"
```

## 📈 Метрики и отчеты

### Deployment Metrics

```yaml
# .github/workflows/metrics.yml
name: Collect Metrics

on:
  workflow_run:
    workflows: ["Deploy"]
    types:
      - completed

jobs:
  collect-metrics:
    runs-on: ubuntu-latest
    steps:
      - name: Calculate Deployment Time
        run: |
          DEPLOYMENT_TIME=$(($(date +%s) - $(date -d "${{ github.event.workflow_run.created_at }}" +%s)))
          echo "Deployment time: ${DEPLOYMENT_TIME}s"
          
      - name: Calculate Success Rate
        run: |
          # Логика расчета успешности развертываний
          
      - name: Generate Report
        run: |
          # Генерация отчета по метрикам
```

### Quality Gates

```yaml
# .github/workflows/quality-gate.yml
name: Quality Gate

on:
  pull_request:
    branches: [ main ]

jobs:
  quality-check:
    runs-on: ubuntu-latest
    steps:
      - name: Code Coverage Check
        run: |
          # Проверка покрытия кода тестами
          if [ "$COVERAGE" -lt 80 ]; then
            echo "❌ Code coverage below 80%"
            exit 1
          fi
          
      - name: Security Scan Check
        run: |
          # Проверка безопасности
          if [ "$VULNERABILITIES" -gt 0 ]; then
            echo "❌ Security vulnerabilities found"
            exit 1
          fi
          
      - name: Performance Check
        run: |
          # Проверка производительности
          if [ "$RESPONSE_TIME" -gt 1000 ]; then
            echo "❌ Response time too high"
            exit 1
          fi
```

## 🔮 Планы развития

### Краткосрочные (3-6 месяцев)
- [ ] Автоматизация тестирования производительности
- [ ] Интеграция с системами мониторинга (Prometheus, Grafana)
- [ ] Автоматическое создание релизов

### Среднесрочные (6-12 месяцев)
- [ ] Canary deployments
- [ ] Feature flags и A/B тестирование
- [ ] Автоматическое масштабирование

### Долгосрочные (1+ год)
- [ ] GitOps подход
- [ ] Multi-cloud deployments
- [ ] AI-powered deployment decisions

## 📚 Дополнительные ресурсы

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/)
- [Docker Security Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [CI/CD Pipeline Design](https://martinfowler.com/articles/cd.html)
