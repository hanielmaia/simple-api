variable "name" { type = string }
variable "alert_email" { type = string }
variable "cluster_name" { type = string }
variable "service_name" { type = string }
variable "db_identifier" { type = string }

variable "alb_arn_suffix" {
  type    = string
  default = null
}

variable "target_group_arn_suffix" {
  type    = string
  default = null
}

variable "api_id" {
  type    = string
  default = null
}

variable "budget_limit_usd" {
  description = "Limite mensal do Budget (0 = não cria)"
  type        = number
  default     = 0
}

variable "tags" {
  type    = map(string)
  default = {}
}
