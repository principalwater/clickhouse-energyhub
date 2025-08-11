######################################################################
# --- Section: Local service enable flags ---
# Service selection logic is in locals.tf
######################################################################
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.6.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.3"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
    }
  }
}

######################################################################
# --- Section: Docker Network ---
######################################################################
resource "docker_network" "metanet1" {
  count  = local.any_bi_tool_enabled ? 1 : 0
  name   = "metanet1"
  driver = "bridge"
}

######################################################################
# --- Section: Postgres - image, container, init_db, restore_if_empty ---
######################################################################
resource "docker_image" "postgres" {
  count = local.any_bi_tool_enabled ? 1 : 0
  name  = "postgres:${var.postgres_version}"
}

resource "docker_container" "postgres" {
  count    = local.any_bi_tool_enabled ? 1 : 0
  name     = "postgres"
  image    = docker_image.postgres[0].name
  hostname = "postgres"
  networks_advanced {
    name    = docker_network.metanet1[0].name
    aliases = ["postgres"]
  }
  env = [
    "POSTGRES_USER=postgres",
    "POSTGRES_PASSWORD=${local.effective_postgres_superuser_password}"
  ]
  restart = "unless-stopped"
  volumes {
    host_path      = abspath(var.bi_postgres_data_path)
    container_path = "/var/lib/postgresql/data"
  }
  healthcheck {
    test     = ["CMD-SHELL", "pg_isready -U postgres"]
    interval = "10s"
    timeout  = "5s"
    retries  = 5
  }
}
######################################################################
# --- Section: Postgres - Metabase DB/user initialization (one-time if pgdata directory is empty) ---
# Creates Metabase user and database if data directory is empty.
######################################################################
resource "null_resource" "init_metabase_db" {
  count = local.metabase_enabled ? 1 : 0
  provisioner "local-exec" {
    command     = <<EOT
      # Wait for Postgres readiness (up to 60 sec)
      for i in {1..30}; do
        docker exec -i postgres pg_isready -U postgres && break || sleep 2
      done
      # Check if user exists
      USER_EXISTS=$(docker exec -i postgres psql -U postgres -d postgres -tc "SELECT 1 FROM pg_roles WHERE rolname = '${var.metabase_pg_user}'" | grep -q 1 && echo yes || echo no)
      if [ "$USER_EXISTS" = "no" ]; then
        echo "Creating Metabase user: ${var.metabase_pg_user}"
        docker exec -i postgres psql -U postgres -d postgres -c "CREATE USER ${var.metabase_pg_user} WITH PASSWORD '${local.effective_metabase_pg_password}';"
      else
        echo "Updating password for Metabase user: ${var.metabase_pg_user}"
        docker exec -i postgres psql -U postgres -d postgres -c "ALTER USER ${var.metabase_pg_user} WITH PASSWORD '${local.effective_metabase_pg_password}';"
      fi
      # Check if Metabase DB exists
      DB_EXISTS=$(docker exec -i postgres psql -U postgres -d postgres -tc "SELECT 1 FROM pg_database WHERE datname = '${var.metabase_pg_db}'" | grep -q 1 && echo yes || echo no)
      if [ "$DB_EXISTS" = "no" ]; then
        echo "Creating Metabase database: ${var.metabase_pg_db}"
        docker exec -i postgres createdb -U postgres ${var.metabase_pg_db}
      fi
      # Grant CREATE and USAGE on schema public in metabase DB to metabase user
      echo "Granting CREATE, USAGE on schema public to ${var.metabase_pg_user} in ${var.metabase_pg_db}"
      docker exec -i postgres psql -U postgres -d ${var.metabase_pg_db} -c "GRANT CREATE, USAGE ON SCHEMA public TO ${var.metabase_pg_user};"
      docker exec -i postgres psql -U postgres -d ${var.metabase_pg_db} -c "GRANT CREATE ON DATABASE ${var.metabase_pg_db} TO ${var.metabase_pg_user};"
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [docker_container.postgres[0]]
}

######################################################################
# --- Section: Postgres - Restore/init DB if data directory is empty ---
# Demonstrates logic for restoring from backup if directory is empty.
######################################################################
resource "null_resource" "postgres_restore_if_empty" {
  count = local.any_bi_tool_enabled && local.postgres_restore_enabled ? 1 : 0
  provisioner "local-exec" {
    command     = <<EOT
if [ -z "$(ls -A "${abspath(var.bi_postgres_data_path)}" 2>/dev/null)" ]; then
  echo "Postgres data dir empty. Restore needed."
  # Здесь должна быть команда восстановления из backup (например, pg_restore ...), требует дополнительного задания.
else
  echo "Postgres data dir not empty. Skipping restore."
fi
EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [docker_container.postgres[0]]
}

######################################################################
# --- Section: Metabase - image, container, api_init ---
######################################################################
resource "docker_image" "metabase" {
  count = local.metabase_enabled ? 1 : 0
  name  = "metabase/metabase:${var.metabase_version}"
}

resource "docker_container" "metabase" {
  count    = local.metabase_enabled ? 1 : 0
  name     = "metabase"
  image    = docker_image.metabase[0].name
  hostname = "metabase"
  ports {
    internal = 3000
    external = var.metabase_port
  }
  volumes {
    host_path      = "/dev/urandom"
    container_path = "/dev/random"
    read_only      = true
  }
  networks_advanced {
    name    = docker_network.metanet1[0].name
    aliases = ["metabase"]
  }
  env = [
    "MB_DB_TYPE=postgres",
    "MB_DB_DBNAME=${var.metabase_pg_db}",
    "MB_DB_PORT=5432",
    "MB_DB_USER=${var.metabase_pg_user}",
    "MB_DB_PASS=${local.effective_metabase_pg_password}",
    "MB_DB_HOST=postgres"
  ]
  restart = "unless-stopped"
  depends_on = [
    docker_container.postgres[0],
    null_resource.postgres_restore_if_empty,
    null_resource.init_metabase_db[0]
  ]
  healthcheck {
    test     = ["CMD-SHELL", "curl --fail -I http://localhost:3000/api/health || exit 1"]
    interval = "15s"
    timeout  = "5s"
    retries  = 5
  }
}
######################################################################
# --- Section: Metabase - API automation (initialization and users) ---
# All Metabase initialization and user creation via API.
######################################################################
resource "null_resource" "metabase_api_init" {
  count = local.metabase_enabled ? 1 : 0
  provisioner "local-exec" {
    command     = <<EOT
set -e
set -o pipefail

METABASE_URL="http://localhost:${var.metabase_port}"
ADMIN_EMAIL="${local.effective_metabase_sa_username}@local.com"
ADMIN_PASSWORD="${local.effective_metabase_sa_password}"
ADMIN_FIRSTNAME="Super"
ADMIN_LASTNAME="Admin"

USERS_JSON=$(jq -c --arg admin_email "$ADMIN_EMAIL" '
  [
    .[] | select(.email == $admin_email)
  ] +
  [
    .[] | select(.email != $admin_email)
  ]
  | map(del(.username))
' <<< '${jsonencode(local.metabase_local_users)}')

# 1. Ждать health API (только status=ok)
for i in {1..48}; do
  STATUS=$(curl -sf "$METABASE_URL/api/health" | jq -r '.status // empty' 2>/dev/null || echo "")
  if [ "$STATUS" = "ok" ]; then
    echo "Metabase is healthy"
    break
  else
    echo "Waiting for Metabase to become healthy..."
    sleep 5
  fi
  if [ $i -eq 48 ]; then
    echo "ERROR: Metabase is not healthy after 4 minutes, aborting"
    exit 1
  fi
done

# 2. Check for setup-token
SETUP_TOKEN=$(curl -sf "$METABASE_URL/api/session/properties" | jq -r '."setup-token" // empty' 2>/dev/null || echo "")


# NB: Metabase requires username field, not email (2024)
SESSION_ID=""
if [ -n "$SETUP_TOKEN" ]; then
  echo "Metabase not initialized, performing setup via API"
  SETUP_PAYLOAD=$(cat <<EOF
{
  "token": "$SETUP_TOKEN",
  "user": {
    "email": "$ADMIN_EMAIL",
    "first_name": "$ADMIN_FIRSTNAME",
    "last_name": "$ADMIN_LASTNAME",
    "password": "$ADMIN_PASSWORD"
  },
  "prefs": {
    "allow_tracking": false,
    "site_name": "Metabase"
  }
}
EOF
)
  RESPONSE=$(curl -sf -X POST \
      -H "Content-type: application/json" \
      "$METABASE_URL/api/setup" \
      -d "$SETUP_PAYLOAD" || true)
  SESSION_ID=$(echo "$RESPONSE" | jq -r '.id // .session_id // empty')
  # Идемпотентно: если setup повторно, Metabase может вернуть already initialized
  if [ -z "$SESSION_ID" ]; then
    # Пробуем логиниться
    LOGIN_PAYLOAD=$(cat <<EOF
{
  "username": "$ADMIN_EMAIL",
  "password": "$ADMIN_PASSWORD"
}
EOF
)
    RESPONSE=$(curl -sf -X POST "$METABASE_URL/api/session" -H "Content-Type: application/json" -d "$LOGIN_PAYLOAD" || true)
    SESSION_ID=$(echo "$RESPONSE" | jq -r '.id // .session_id // empty')
  fi
else
  echo "Metabase already initialized, logging in via /api/session"
  LOGIN_PAYLOAD=$(cat <<EOF
{
  "username": "$ADMIN_EMAIL",
  "password": "$ADMIN_PASSWORD"
}
EOF
)
  RESPONSE=$(curl -sf -X POST "$METABASE_URL/api/session" -H "Content-Type: application/json" -d "$LOGIN_PAYLOAD" || true)
  SESSION_ID=$(echo "$RESPONSE" | jq -r '.id // .session_id // empty')
fi

if [ -z "$SESSION_ID" ]; then
  echo "ERROR: No session_id received after setup/login"
  exit 1
fi

# 3. Create other users via /api/user
echo "$USERS_JSON" | jq -c '.[]' | while read -r user; do
  email=$(echo "$user" | jq -r '.email')
  password=$(echo "$user" | jq -r '.password')
  first_name=$(echo "$user" | jq -r '.first_name')
  last_name=$(echo "$user" | jq -r '.last_name')
  is_superuser=$(echo "$user" | jq -r 'if has("is_superuser") then .is_superuser else empty end')

  if [ "$email" = "$ADMIN_EMAIL" ]; then
    echo "Skipping admin user $email"
    continue
  fi

  EXISTING=$(curl -sf -H "X-Metabase-Session: $SESSION_ID" "$METABASE_URL/api/user" | jq -r '.[] | select(.email=="'"$email"'") | .id' || true)
  if [ -n "$EXISTING" ]; then
    echo "User $email already exists (id=$EXISTING), skipping"
    continue
  fi

  if [ -n "$is_superuser" ] && [ "$is_superuser" != "null" ]; then
    USER_PAYLOAD=$(cat <<EOF
{
  "first_name": "$first_name",
  "last_name": "$last_name",
  "email": "$email",
  "password": "$password",
  "is_superuser": $is_superuser
}
EOF
)
  else
    USER_PAYLOAD=$(cat <<EOF
{
  "first_name": "$first_name",
  "last_name": "$last_name",
  "email": "$email",
  "password": "$password"
}
EOF
)
  fi

  CREATE_RESP=$(curl -sf -X POST "$METABASE_URL/api/user" -H "Content-Type: application/json" -H "X-Metabase-Session: $SESSION_ID" -d "$USER_PAYLOAD" || true)
  if echo "$CREATE_RESP" | grep -q '"email".*already'; then
    echo "User $email already exists (race condition), skipping"
    continue
  fi
  if [ -z "$(echo "$CREATE_RESP" | jq -r '.id // empty')" ]; then
    echo "WARNING: Failed to create user $email (non-fatal)"
    echo "Response: $CREATE_RESP"
    continue
  fi
  echo "User $email created"
done
EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [docker_container.metabase[0]]
}

######################################################################
# --- Section: Superset - image, config, init_db, container, post_init, create_local_users ---
######################################################################
# --- Section: Superset config file ---
# Generates Superset configuration file.
######################################################################
resource "local_file" "superset_config" {
  count = local.superset_enabled ? 1 : 0
  content = templatefile("${path.module}/samples/superset/superset_config.py.tmpl", {
    superset_secret_key = var.superset_secret_key
  })
  filename = "${path.root}/../env/superset_config.py"
}

######################################################################
# --- Section: Superset DB init in Postgres ---
# Creates Superset role and database in Postgres.
######################################################################
resource "null_resource" "init_superset_db" {
  count = local.superset_enabled ? 1 : 0
  provisioner "local-exec" {
    command     = <<EOT
      for i in {1..30}; do
        docker exec -i postgres pg_isready -U postgres && break || sleep 3
      done

      # Create superset role if it does not exist (as admin)
      ROLE_EXISTS=$(docker exec -i postgres psql -U postgres -d postgres -tc "SELECT 1 FROM pg_roles WHERE rolname = '${var.superset_pg_user}'" | grep -q 1 && echo yes || echo no)
      if [ "$ROLE_EXISTS" = "no" ]; then
        echo "Creating Superset user: ${var.superset_pg_user}"
        docker exec -i postgres psql -U postgres -d postgres -c "CREATE USER ${var.superset_pg_user} WITH PASSWORD '${local.effective_superset_pg_password}';"
      else
        echo "Superset user ${var.superset_pg_user} already exists, skipping creation"
      fi

      # Create superset database if it does not exist (as admin)
      DB_EXISTS=$(docker exec -i postgres psql -U postgres -d postgres -tc "SELECT 1 FROM pg_database WHERE datname = '${var.superset_pg_db}'" | grep -q 1 && echo yes || echo no)
      if [ "$DB_EXISTS" = "no" ]; then
        echo "Creating Superset database: ${var.superset_pg_db}"
        docker exec -i postgres createdb -U postgres ${var.superset_pg_db}
      else
        echo "Superset database ${var.superset_pg_db} already exists, skipping creation"
      fi

      # Grant all privileges on database to superset user
      echo "Granting all privileges on ${var.superset_pg_db} to ${var.superset_pg_user}"
      docker exec -i postgres psql -U postgres -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE ${var.superset_pg_db} TO ${var.superset_pg_user};"
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [docker_container.postgres[0]]
}

######################################################################
# --- Section: Superset image ---
######################################################################
resource "docker_image" "superset" {
  count = local.superset_enabled ? 1 : 0
  name  = "apache/superset:${var.superset_version}"
}

######################################################################
# --- Section: Superset container ---
######################################################################
resource "docker_container" "superset" {
  count    = local.superset_enabled ? 1 : 0
  name     = "superset"
  image    = docker_image.superset[0].name
  hostname = "superset"
  ports {
    internal = 8088
    external = var.superset_port
  }
  networks_advanced {
    name    = docker_network.metanet1[0].name
    aliases = ["superset"]
  }
  env = [
    "SUPERSET_ENV=production",
    "SUPERSET_DATABASE_URI=postgresql+psycopg2://${var.superset_pg_user}:${local.effective_superset_pg_password}@postgres:5432/${var.superset_pg_db}",
    "SECRET_KEY=${var.superset_secret_key}",
    "PYTHONPATH=/app/pythonpath"
  ]
  volumes {
    host_path      = abspath(local_file.superset_config[0].filename)
    container_path = "/app/pythonpath/superset_config.py"
    read_only      = true
  }
  restart = "unless-stopped"
  depends_on = [
    docker_container.postgres[0],
    null_resource.init_superset_db[0],
    local_file.superset_config[0]
  ]
  healthcheck {
    test     = ["CMD-SHELL", "curl --fail -I http://localhost:8088/health || exit 1"]
    interval = "15s"
    timeout  = "5s"
    retries  = 5
  }
}

######################################################################
# --- Section: Superset post-init (drivers, admin) ---
# Install drivers and initialize Superset after container launch.
######################################################################
resource "null_resource" "superset_post_init" {
  count = local.superset_enabled ? 1 : 0
  provisioner "local-exec" {
    command     = <<EOT
      # Wait for Superset container to become healthy (up to 150 seconds)
      for i in {1..30}; do
        docker exec superset curl -sf http://localhost:8088/health && break || sleep 5
      done

      # Upgrade pip and install ClickHouse drivers inside Superset container
      echo "Upgrading pip and installing ClickHouse drivers in Superset container"
      docker exec superset pip install --upgrade pip
      docker exec superset pip install clickhouse-connect clickhouse-driver

      # Restart Superset container to load new libraries
      echo "Restarting Superset container to apply new libraries"
      docker restart superset

      # Wait again for Superset to become healthy after restart
      for i in {1..30}; do
        docker exec superset curl -sf http://localhost:8088/health && break || sleep 5
      done

      # Initialize Superset database and create admin user (using local effective admin user variables)
      echo "Initializing Superset database and creating admin user"
      docker exec superset superset db upgrade
      docker exec superset superset init
      docker exec superset superset fab create-admin \
        --username "${local.effective_superset_sa_username}" \
        --firstname "Super" --lastname "User" \
        --email "${local.effective_superset_sa_username}@local" \
        --password "${local.effective_superset_sa_password}" || true

      # Create regular Superset users from local.superset_local_users (role Gamma by default, except admin)
      echo '${jsonencode(local.superset_local_users)}' | jq -c '.[]' | while read -r user; do
        username=$(echo "$user" | jq -r '.username')
        password=$(echo "$user" | jq -r '.password')
        first_name=$(echo "$user" | jq -r '.first_name')
        last_name=$(echo "$user" | jq -r '.last_name')
        is_admin=$(echo "$user" | jq -r '.is_admin')

        if [ "$is_admin" = "true" ]; then
          continue
        fi

        echo "Creating regular Superset user: $username"
        docker exec superset superset fab create-user \
          --username "$username" \
          --firstname "$first_name" --lastname "$last_name" \
          --email "$username@local" \
          --password "$password" \
          --role "Gamma" || true
      done
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [docker_container.superset[0]]
}

######################################################################
# --- Section: Superset user automation ---
# Creates Superset users from local.superset_local_users variable.
######################################################################
resource "null_resource" "superset_create_local_users" {
  count = local.superset_enabled ? 1 : 0
  provisioner "local-exec" {
    command     = <<EOT
  set -e
  set -x

  # Wait for Superset to become healthy (up to 150 seconds)
  for i in {1..30}; do
    if docker exec superset curl -sf http://localhost:8088/health; then
      echo "Superset is healthy"
      break
    else
      echo "Waiting for Superset to be healthy..."
      sleep 5
    fi
  done

  USERS_JSON='${jsonencode(local.superset_local_users)}'
  echo "Superset users JSON: $USERS_JSON"

  echo "$USERS_JSON" | jq -c '.[]' | while read -r user; do
    echo "---- User block ----"
    echo "Raw user: $user"
    username=$(echo "$user" | jq -r '.username')
    password=$(echo "$user" | jq -r '.password')
    first_name=$(echo "$user" | jq -r '.first_name')
    last_name=$(echo "$user" | jq -r '.last_name')
    is_admin=$(echo "$user" | jq -r '.is_admin')

    echo "Processing user: $username, admin: $is_admin"

    # Check if user exists
    EXISTS=$(docker exec superset superset fab list-users | grep -w "$username" || true)
    echo "User existence check for '$username': $${EXISTS:-not found}"

    if [ -n "$EXISTS" ]; then
      echo "User $username already exists, skipping creation"
      echo "--------------------"
      continue
    fi

    if [ "$is_admin" = "true" ]; then
      echo "CMD: docker exec superset superset fab create-admin --username \"$username\" --firstname \"$first_name\" --lastname \"$last_name\" --email \"$username@local\" --password \"*****\""
      docker exec superset superset fab create-admin \
        --username "$username" \
        --firstname "$first_name" --lastname "$last_name" \
        --email "$username@local" \
        --password "$password"
      echo "Return code: $?"
    else
      echo "CMD: docker exec superset superset fab create-user --username \"$username\" --firstname \"$first_name\" --lastname \"$last_name\" --email \"$username@local\" --password \"*****\" --role \"Gamma\""
      docker exec superset superset fab create-user \
        --username "$username" \
        --firstname "$first_name" --lastname "$last_name" \
        --email "$username@local" \
        --password "$password" \
        --role "Gamma"
      echo "Return code: $?"
    fi
    echo "--------------------"
  done
EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [docker_container.superset[0]]
}
