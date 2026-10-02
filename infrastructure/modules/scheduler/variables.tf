variable "name" { type = string }
variable "cluster_name" { type = string }
variable "service_name" { type = string }
variable "ecs_service_arn" { type = string }

variable "desired_count" {
  description = "Quantidade de tasks ao religar"
  type        = number
}

variable "scale_down_cron" {
  type    = string
  default = "cron(0 20 ? * MON-FRI *)"
}

variable "scale_up_cron" {
  type    = string
  default = "cron(0 8 ? * MON-FRI *)"
}

variable "timezone" {
  type    = string
  default = "America/Sao_Paulo"
}

variable "tags" {
  type    = map(string)
  default = {}
}
