variable "role_name" { type = string }

variable "github_repo" {
  description = "owner/repo autorizado a assumir a role"
  type        = string
}

variable "branch" {
  description = "Branch autorizada a fazer deploy"
  type        = string
  default     = "main"
}

variable "create_provider" {
  description = "Cria o OIDC provider do GitHub (false se já existir na conta)"
  type        = bool
  default     = true
}

variable "ecr_repository_arn" { type = string }
variable "ecs_service_arn" { type = string }

variable "pass_role_arns" {
  description = "Roles que a pipeline pode repassar à task (execution + task role)"
  type        = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
