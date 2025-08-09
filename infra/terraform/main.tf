###############################################################################
# Terraform ClickHouse cluster with S3 backup and storage capabilities
###############################################################################

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.6.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "6.4.0"
    }
  }
}

# --- Providers ---
provider "docker" {}

provider "docker" {
  alias = "remote_host"
  host  = "ssh://${var.remote_ssh_user}@${var.remote_host_name}"
  # ssh_opts убран, чтобы Terraform использовал ssh-agent и ~/.ssh/config
}

provider "aws" {
  alias      = "remote_backup"
  access_key = var.minio_root_user
  secret_key = var.minio_root_password
  region     = "us-east-1" # minio requires a region
  endpoints {
    s3 = "http://${var.remote_host_name}:${var.remote_minio_port}"
  }
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

provider "aws" {
  alias      = "local_storage"
  access_key = var.minio_root_user
  secret_key = var.minio_root_password
  region     = "us-east-1" # minio requires a region
  endpoints {
    s3 = "http://localhost:${var.local_minio_port}"
  }
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}


# --- Locals ---
locals {
  super_user_name            = var.super_user_name
  bi_user_name               = var.bi_user_name
  super_user_password_sha256 = sha256(var.super_user_password)
  bi_user_password_sha256    = sha256(var.bi_user_password)
  cluster_name               = "dwh_test"

  keeper_nodes = [
    { name = "clickhouse-keeper-01", id = 1, host = "clickhouse-keeper-01", tcp_port = 9181, raft_port = 9234 },
    { name = "clickhouse-keeper-02", id = 2, host = "clickhouse-keeper-02", tcp_port = 9181, raft_port = 9234 },
    { name = "clickhouse-keeper-03", id = 3, host = "clickhouse-keeper-03", tcp_port = 9181, raft_port = 9234 },
  ]

  clickhouse_nodes = [
    { name = "clickhouse-01", shard = 1, replica = 1, host = "clickhouse-01", http_port = var.use_standard_ports ? var.ch_http_port : 8123, tcp_port = var.use_standard_ports ? var.ch_tcp_port : 9000 },
    { name = "clickhouse-02", shard = 2, replica = 1, host = "clickhouse-02", http_port = var.use_standard_ports ? var.ch_http_port : 8124, tcp_port = var.use_standard_ports ? var.ch_tcp_port : 9001 },
    { name = "clickhouse-03", shard = 1, replica = 2, host = "clickhouse-03", http_port = var.use_standard_ports ? var.ch_http_port : 8125, tcp_port = var.use_standard_ports ? var.ch_tcp_port : 9002 },
    { name = "clickhouse-04", shard = 2, replica = 2, host = "clickhouse-04", http_port = var.use_standard_ports ? var.ch_http_port : 8126, tcp_port = var.use_standard_ports ? var.ch_tcp_port : 9003 },
  ]

  remote_servers = [
    { shard = 1, replicas = [{ host = "clickhouse-01", port = var.use_standard_ports ? var.ch_tcp_port : 9000 }, { host = "clickhouse-03", port = var.use_standard_ports ? var.ch_tcp_port : 9002 }] },
    { shard = 2, replicas = [{ host = "clickhouse-02", port = var.use_standard_ports ? var.ch_tcp_port : 9001 }, { host = "clickhouse-04", port = var.use_standard_ports ? var.ch_tcp_port : 9003 }] },
  ]
}

# --- Resources ---

# Network
resource "docker_network" "ch_net" {
  name = "clickhouse-net"
}

# Images
resource "docker_image" "clickhouse_server" {
  name = "clickhouse/clickhouse-server:${var.ch_version}"
}
resource "docker_image" "clickhouse_keeper" {
  name = "clickhouse/clickhouse-keeper:${var.chk_version}"
}
resource "docker_image" "minio" {
  name = "minio/minio:${var.minio_version}"
}
resource "docker_image" "clickhouse_backup" {
  name = "altinity/clickhouse-backup:2.5.6"
}

# ClickHouse Dirs and Configs
resource "null_resource" "mk_clickhouse_dirs" {
  for_each = { for n in local.clickhouse_nodes : n.name => n }
  provisioner "local-exec" {
    command = "mkdir -p ${var.clickhouse_base_path}/${each.key}/etc/clickhouse-server/config.d ${var.clickhouse_base_path}/${each.key}/etc/clickhouse-server/users.d ${var.clickhouse_base_path}/${each.key}/data ${var.clickhouse_base_path}/${each.key}/logs"
  }
}

resource "local_file" "users_xml" {
  for_each = { for n in local.clickhouse_nodes : n.name => n }
  content = templatefile("${path.module}/samples/users.xml.tpl", {
    super_user_name            = local.super_user_name
    super_user_password_sha256 = local.super_user_password_sha256
    bi_user_name               = local.bi_user_name
    bi_user_password_sha256    = local.bi_user_password_sha256
  })
  filename   = "${var.clickhouse_base_path}/${each.key}/etc/clickhouse-server/users.d/users.xml"
  depends_on = [null_resource.mk_clickhouse_dirs]
}

resource "local_file" "config_xml" {
  for_each = { for n in local.clickhouse_nodes : n.name => n }
  content = templatefile("${path.module}/samples/config.xml.tpl", {
    node                = each.value
    remote_servers      = local.remote_servers
    keepers             = local.keeper_nodes
    cluster_name        = local.cluster_name
    super_user_name     = local.super_user_name
    super_user_password = var.super_user_password
    local_minio_port    = var.local_minio_port
    minio_root_user     = var.minio_root_user
    minio_root_password = var.minio_root_password
    storage_type        = var.storage_type
    remote_host_name    = var.remote_host_name
    ch_replication_port = var.ch_replication_port
  })
  filename   = "${var.clickhouse_base_path}/${each.key}/etc/clickhouse-server/config.d/config.xml"
  depends_on = [null_resource.mk_clickhouse_dirs]
}

# Keeper
resource "null_resource" "mk_keeper_dirs" {
  for_each = { for k in local.keeper_nodes : k.name => k }
  provisioner "local-exec" {
    command = <<EOT
      mkdir -p ${var.clickhouse_base_path}/${each.key}/etc/clickhouse-keeper
      mkdir -p ${var.clickhouse_base_path}/${each.key}/data/coordination/log
      mkdir -p ${var.clickhouse_base_path}/${each.key}/data/coordination/snapshots
      mkdir -p ${var.clickhouse_base_path}/${each.key}/logs
    EOT
  }
}

resource "local_file" "keeper_config" {
  for_each = { for k in local.keeper_nodes : k.name => k }
  content = templatefile("${path.module}/samples/keeper_config.xml.tpl", {
    keeper      = each.value
    keepers_all = local.keeper_nodes
  })
  filename   = "${var.clickhouse_base_path}/${each.key}/etc/clickhouse-keeper/keeper_config.xml"
  depends_on = [null_resource.mk_keeper_dirs]
}

resource "docker_container" "keeper" {
  for_each = { for k in local.keeper_nodes : k.name => k }
  name     = each.key
  hostname = each.key
  image    = docker_image.clickhouse_keeper.name
  user     = "${var.ch_uid}:${var.ch_gid}"
  networks_advanced {
    name    = docker_network.ch_net.name
    aliases = [each.key]
  }
  restart = "unless-stopped"
  mounts {
    target    = "/etc/clickhouse-keeper/keeper_config.xml"
    source    = abspath("${var.clickhouse_base_path}/${each.key}/etc/clickhouse-keeper/keeper_config.xml")
    type      = "bind"
    read_only = true
  }
  mounts {
    target = "/var/lib/clickhouse/coordination"
    source = abspath("${var.clickhouse_base_path}/${each.key}/data/coordination")
    type   = "bind"
  }
  mounts {
    target = "/var/log/clickhouse-keeper"
    source = abspath("${var.clickhouse_base_path}/${each.key}/logs")
    type   = "bind"
  }
  depends_on = [null_resource.mk_keeper_dirs, local_file.keeper_config]
}

# ClickHouse Nodes
resource "docker_container" "ch_nodes" {
  for_each = { for n in local.clickhouse_nodes : n.name => n }
  name     = each.key
  image    = docker_image.clickhouse_server.name
  memory   = var.memory_limit
  user     = "${var.ch_uid}:${var.ch_gid}"
  networks_advanced {
    name    = docker_network.ch_net.name
    aliases = [each.key]
  }
  dynamic "ports" {
    for_each = each.key == "clickhouse-01" ? [1] : []
    content {
      internal = var.use_standard_ports ? var.ch_http_port : each.value.http_port
      external = var.use_standard_ports ? var.ch_http_port : each.value.http_port
    }
  }
  dynamic "ports" {
    for_each = each.key == "clickhouse-01" ? [1] : []
    content {
      internal = var.use_standard_ports ? var.ch_tcp_port : each.value.tcp_port
      external = var.use_standard_ports ? var.ch_tcp_port : each.value.tcp_port
    }
  }
  restart = "unless-stopped"
  mounts {
    target    = "/etc/clickhouse-server/config.d/config.xml"
    source    = abspath("${var.clickhouse_base_path}/${each.key}/etc/clickhouse-server/config.d/config.xml")
    type      = "bind"
    read_only = true
  }
  mounts {
    target    = "/etc/clickhouse-server/users.d/users.xml"
    source    = abspath("${var.clickhouse_base_path}/${each.key}/etc/clickhouse-server/users.d/users.xml")
    type      = "bind"
    read_only = true
  }
  mounts {
    target = "/var/lib/clickhouse"
    source = abspath("${var.clickhouse_base_path}/${each.key}/data")
    type   = "bind"
  }
  mounts {
    target = "/var/log/clickhouse-server"
    source = abspath("${var.clickhouse_base_path}/${each.key}/logs")
    type   = "bind"
  }
  depends_on = [docker_container.keeper, local_file.config_xml, local_file.users_xml, null_resource.minio_buckets]
}

# --- MinIO (S3) ---

resource "null_resource" "mk_local_minio_dir" {
  count = var.storage_type == "s3_ssd" ? 1 : 0
  provisioner "local-exec" {
    command = "mkdir -p ${var.local_minio_path}"
  }
}

# Local MinIO for S3-based storage
resource "docker_container" "minio_local" {
  count   = var.storage_type == "s3_ssd" ? 1 : 0
  name    = "minio-local-storage"
  image   = docker_image.minio.name
  restart = "always"
  networks_advanced {
    name = docker_network.ch_net.name
  }
  ports {
    internal = 9000
    external = var.local_minio_port
  }
  ports {
    internal = 9001
    external = var.local_minio_port + 1
  }
  mounts {
    source = abspath(var.local_minio_path)
    target = "/data"
    type   = "bind"
  }
  env        = ["MINIO_ROOT_USER=${var.minio_root_user}", "MINIO_ROOT_PASSWORD=${var.minio_root_password}", "CONSOLE_AGPL_LICENSE_ACCEPTED=yes"]
  command    = ["server", "/data", "--console-address", ":9001"]
  depends_on = [null_resource.mk_local_minio_dir]
}

# Remote MinIO for backups
resource "docker_container" "minio_remote_backup" {
  provider = docker.remote_host
  name     = "minio-remote-backup"
  image    = docker_image.minio.name
  restart  = "always"
  ports {
    internal = 9000
    external = var.remote_minio_port
  }
  ports {
    internal = 9001
    external = var.remote_minio_port + 1
  }
  volumes {
    host_path      = var.remote_minio_path
    container_path = "/data"
  }
  env     = ["MINIO_ROOT_USER=${var.minio_root_user}", "MINIO_ROOT_PASSWORD=${var.minio_root_password}", "CONSOLE_AGPL_LICENSE_ACCEPTED=yes"]
  command = ["server", "/data", "--console-address", ":9001"]
}

# Health Checks for MinIO
resource "null_resource" "wait_for_remote_minio" {
  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for MinIO to be ready...'",
      "for i in {1..30}; do",
      "  if curl -s http://localhost:${var.remote_minio_port}/minio/health/live &> /dev/null; then",
      "    echo 'MinIO is ready!'",
      "    break",
      "  fi",
      "  echo 'Waiting for MinIO... attempt $i/30'",
      "done"
    ]
    connection {
      type = "ssh"
      user = var.remote_ssh_user
      host = var.remote_host_name
    }
  }
  depends_on = [docker_container.minio_remote_backup]
}

resource "null_resource" "wait_for_local_minio" {
  count = var.storage_type == "s3_ssd" ? 1 : 0
  provisioner "local-exec" {
    command = <<EOT
      for i in {1..30}; do
        if curl -s "http://localhost:${var.local_minio_port}/minio/health/live" &> /dev/null; then
          echo "Local MinIO is ready!"
          break
        fi
        echo "Attempt $i/30 - Local MinIO not ready yet, waiting 10 seconds..."
        sleep 10
      done
    EOT
  }
  depends_on = [docker_container.minio_local]
}

# --- S3 Buckets ---
resource "null_resource" "minio_buckets" {
  provisioner "local-exec" {
    command = "mc alias set remote_backup http://${var.remote_host_name}:${var.remote_minio_port} ${var.minio_root_user} ${var.minio_root_password} --api S3v4 && mc mb --ignore-existing remote_backup/${var.bucket_backup}"
  }

  provisioner "local-exec" {
    command = var.storage_type == "s3_ssd" ? "mc alias set local_storage http://localhost:${var.local_minio_port} ${var.minio_root_user} ${var.minio_root_password} --api S3v4 && mc mb --ignore-existing local_storage/${var.bucket_storage}" : "echo 'Skipping local bucket creation'"
  }

  depends_on = [
    null_resource.wait_for_remote_minio,
    null_resource.wait_for_local_minio
  ]
}

# --- ClickHouse Backup ---
resource "docker_container" "clickhouse_backup" {
  name    = "clickhouse-backup"
  image   = docker_image.clickhouse_backup.name
  command = ["server"] # Run API server to keep container alive
  networks_advanced {
    name = docker_network.ch_net.name
  }
  mounts {
    target    = "/var/lib/clickhouse"
    source    = abspath("${var.clickhouse_base_path}/clickhouse-01/data")
    type      = "bind"
    read_only = false
  }
  mounts {
    target    = "/etc/clickhouse-server"
    source    = abspath("${var.clickhouse_base_path}/clickhouse-01/etc/clickhouse-server")
    type      = "bind"
    read_only = true
  }
  env = [
    "CLICKHOUSE_HOST=clickhouse-01",
    "CLICKHOUSE_PORT=9000",
    "CLICKHOUSE_USERNAME=${var.super_user_name}",
    "CLICKHOUSE_PASSWORD=${var.super_user_password}",
    "REMOTE_STORAGE=s3",
    "S3_BUCKET=clickhouse-backups",
    "S3_ACCESS_KEY=${var.minio_root_user}",
    "S3_SECRET_KEY=${var.minio_root_password}",
    "S3_ENDPOINT=http://${var.remote_host_name}:${var.remote_minio_port}",
    "S3_REGION=us-east-1",
    "S3_DISABLE_SSL=true",
    "S3_FORCE_PATH_STYLE=true"
  ]
  depends_on = [docker_container.ch_nodes, null_resource.minio_buckets]
}

# .env file
resource "null_resource" "mk_env_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${path.root}/../env"
  }
}

resource "local_file" "env_file" {
  content    = <<EOT
CH_USER=${local.super_user_name}
CH_PASSWORD=${var.super_user_password}
BI_USER=${local.bi_user_name}
BI_PASSWORD=${var.bi_user_password}
MINIO_USER=${var.minio_root_user}
MINIO_PASSWORD=${var.minio_root_password}
EOT
  filename   = "${path.root}/../env/clickhouse.env"
  depends_on = [null_resource.mk_env_dir]
}
