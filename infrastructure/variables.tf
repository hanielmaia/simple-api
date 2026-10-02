#==========================================================================
# PROJECT
#==========================================================================
variable "project_name" { type = string }
variable "environment" { type = string }
variable "region" { type = string }

variable "owner" {
  description = "Tag Owner (FinOps)"
  type        = string
  default     = "devops"
}

#==========================================================================
# NETWORK
#==========================================================================
variable "vpc_cidr_block" { type = string }
variable "availability_zones_public" { type = list(string) }
variable "availability_zones_private" { type = list(string) }
variable "public_subnet_names" { type = list(string) }
variable "private_subnet_names" { type = list(string) }
variable "subnet_cidr_blocks_public" { type = list(string) }
variable "subnet_cidr_blocks_private" { type = list(string) }

variable "tags_vpc" { type = map(string) }
variable "tags_public_subnet" { type = map(string) }
variable "tags_private_subnet" { type = map(string) }
variable "tags_internet_gateway" { type = map(string) }
variable "tags_rt_public" { type = map(string) }
variable "tags_rt_private" { type = map(string) }

variable "nat_per_az" {
  description = "true = 1 NAT por AZ (HA, mais caro); false = NAT único (FinOps)"
  type        = bool
  default     = false
}

#==========================================================================
# APPLICATION / ALB / ECS
#==========================================================================
variable "app_port" {
  description = "Porta da aplicação (deve casar com config/security_rules/*.json)"
  type        = number
  default     = 3000
}

variable "health_check_path" {
  type    = string
  default = "/"
}

variable "container_image_tag" {
  description = "Tag da imagem no ECR usada na task definition inicial (o CI/CD publica novas revisions)"
  type        = string
  default     = "bootstrap"
}

variable "task_cpu" {
  type    = number
  default = 256
}

variable "task_memory" {
  type    = number
  default = 512
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "log_retention_in_days" {
  type    = number
  default = 14
}

variable "ecr_max_images" {
  type    = number
  default = 10
}

#==========================================================================
# RDS
#==========================================================================
variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_username" {
  type    = string
  default = "appuser"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_multi_az" {
  type    = bool
  default = false
}

variable "db_backup_retention_days" {
  type    = number
  default = 7
}

variable "db_deletion_protection" {
  type    = bool
  default = false
}

variable "db_skip_final_snapshot" {
  type    = bool
  default = true
}

#==========================================================================
# CI/CD
#==========================================================================
variable "github_repo" {
  description = "owner/repo do GitHub autorizado a fazer deploy"
  type        = string
  default     = "hanielmaia/simple-api"
}

variable "github_branch" {
  type    = string
  default = "main"
}

variable "create_github_oidc_provider" {
  description = "Só um provider OIDC do GitHub pode existir por conta: true em apenas um ambiente"
  type        = bool
  default     = true
}

variable "github_oidc_extra_subject_prefixes" {
  description = "Prefixos extras do claim sub (repos com 'immutable subject claims' emitem repo:owner@id/repo@id)"
  type        = list(string)
  default     = []
}

#==========================================================================
# EXPOSIÇÃO, RESILIÊNCIA E FINOPS
#==========================================================================
variable "expose_mode" {
  description = "alb = ALB público (resiliência, prod); apigw = API Gateway + VPC Link + Cloud Map (sem custo fixo de ALB)"
  type        = string
  default     = "alb"

  validation {
    condition     = contains(["alb", "apigw"], var.expose_mode)
    error_message = "expose_mode deve ser \"alb\" ou \"apigw\"."
  }
}

variable "use_spot" {
  description = "Fargate Spot (mais barato, interrompível): só fora de produção"
  type        = bool
  default     = false
}

variable "autoscaling_max_capacity" {
  description = "Máximo de tasks no autoscaling por CPU (<= desired_count desativa)"
  type        = number
  default     = 0
}

variable "schedule_enabled" {
  description = "Zera as tasks fora do horário comercial (não usar em prod)"
  type        = bool
  default     = false
}

variable "scale_down_cron" {
  type    = string
  default = "cron(0 20 ? * MON-FRI *)"
}

variable "scale_up_cron" {
  type    = string
  default = "cron(0 8 ? * MON-FRI *)"
}

variable "alert_email" {
  description = "E-mail para alarmes e Budget (vazio = não cria)"
  type        = string
  default     = ""
}

variable "budget_limit_usd" {
  description = "Limite mensal do Budget em USD (0 = não cria); crie em um único ambiente"
  type        = number
  default     = 0
}
