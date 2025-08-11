variable "portainer_version" {
  description = "Версия Portainer CE."
  type        = string
}

variable "portainer_https_port" {
  description = "Порт для HTTPS-интерфейса Portainer."
  type        = number
}

variable "portainer_agent_port" {
  description = "Порт для Docker agent."
  type        = number
}
