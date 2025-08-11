terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.6.1"
    }
  }
}

# --- Portainer Module ---

resource "docker_image" "portainer" {
  name = "portainer/portainer-ce:${var.portainer_version}"
}

resource "docker_volume" "portainer_data" {
  name = "portainer_data"
}

resource "docker_container" "portainer" {
  name     = "portainer"
  image    = docker_image.portainer.name
  hostname = "portainer"
  restart  = "unless-stopped"

  ports {
    internal = 9000
    external = var.portainer_agent_port
  }

  ports {
    internal = 9443
    external = var.portainer_https_port
  }

  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }

  volumes {
    volume_name    = docker_volume.portainer_data.name
    container_path = "/data"
  }
}
