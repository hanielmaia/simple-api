variable "cluster_name" {
  description = "Nome do cluster ECS"
  type        = string
}

variable "service_name" {
  description = "Nome do serviço ECS (também usado como family da task definition)"
  type        = string
}

variable "region" {
  description = "Região AWS usada para configuração de logs"
  type        = string
}

variable "container_name" {
  description = "Nome do container dentro da task definition"
  type        = string
}

variable "container_image" {
  description = "URI da imagem do container (ex: ECR)"
  type        = string
}

variable "container_port" {
  description = "Porta em que a aplicação escuta dentro do container"
  type        = number
  default     = 3000
}

variable "task_cpu" {
  description = "CPU alocada para a task (unidades Fargate)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Memória alocada para a task (MiB)"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Quantidade desejada de tasks em execução"
  type        = number
  default     = 1
}

variable "execution_role_arn" {
  description = "ARN da IAM Role de execução da task (pull de imagem, logs, secrets)"
  type        = string
}

variable "task_role_arn" {
  description = "ARN da IAM Role da aplicação (permissões em runtime)"
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Lista de subnets onde as tasks serão executadas"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Lista de Security Groups associados às tasks"
  type        = list(string)
}

variable "assign_public_ip" {
  description = "Se as tasks devem receber IP público (necessário em subnets públicas sem NAT)"
  type        = bool
  default     = false
}

variable "target_group_arn" {
  description = "ARN do Target Group para registrar as tasks (null quando não há LB)"
  type        = string
  default     = null
}

variable "environment_variables" {
  description = "Variáveis de ambiente injetadas no container"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "secrets" {
  description = "Secrets injetados no container a partir do SSM/Secrets Manager"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

variable "container_insights" {
  description = "Habilita o Container Insights no cluster"
  type        = bool
  default     = false
}

variable "log_retention_in_days" {
  description = "Retenção dos logs no CloudWatch"
  type        = number
  default     = 14
}

variable "tags" {
  description = "Tags aplicadas aos recursos ECS"
  type        = map(string)
  default     = {}
}

variable "use_spot" {
  description = "Usa Fargate Spot (mais barato, pode ser interrompido): recomendado só fora de produção"
  type        = bool
  default     = false
}

variable "health_check_grace_period" {
  description = "Segundos que o ECS ignora health checks do LB após subir a task"
  type        = number
  default     = 30
}

variable "service_registry_arn" {
  description = "ARN do serviço Cloud Map onde as tasks se registram (null = sem service discovery)"
  type        = string
  default     = null
}

variable "autoscaling_max_capacity" {
  description = "Máximo de tasks do autoscaling (<= desired_count desativa)"
  type        = number
  default     = 0
}

variable "autoscaling_cpu_target" {
  description = "CPU média alvo (%) do target tracking"
  type        = number
  default     = 60
}
