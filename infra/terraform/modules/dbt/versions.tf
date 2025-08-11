terraform {
  required_version = ">= 1.0"
  
  required_providers {
    docker = {
      source                = "kreuzwerker/docker"
      version               = ">= 3.0.0"
      configuration_aliases = [docker.remote_host]
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0.0"
    }
  }
}
