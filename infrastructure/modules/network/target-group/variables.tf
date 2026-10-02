variable "name" {
  description = "Nome do target group"
  type        = string
}

variable "port" {
  description = "Porta em que o target group encaminha o tráfego (porta da aplicação)"
  type        = number
}

variable "protocol" {
  description = "Protocolo do target group e do health check"
  type        = string
  default     = "HTTP"
}

variable "vpc_id" {
  description = "ID da VPC onde o target group será criado"
  type        = string
}

variable "target_type" {
  description = "Tipo de destino do target group (ip para Fargate awsvpc)"
  type        = string
  default     = "ip"
}

variable "health_check_path" {
  description = "Path usado no health check"
  type        = string
  default     = "/"
}

variable "health_check_matcher" {
  description = "Códigos HTTP esperados no health check"
  type        = string
  default     = "200"
}

variable "health_check_interval" {
  description = "Intervalo entre health checks (segundos)"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Timeout do health check (segundos)"
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "Número de checks bem-sucedidos para marcar o target como saudável"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Número de checks falhos para marcar o target como não saudável"
  type        = number
  default     = 3
}

variable "tags" {
  description = "Tags aplicadas ao target group"
  type        = map(string)
  default     = {}
}

variable "deregistration_delay" {
  description = "Segundos de connection draining ao remover um target"
  type        = number
  default     = 30
}
