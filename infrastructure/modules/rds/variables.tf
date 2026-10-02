variable "identifier" {
  type = string
}

variable "engine_version" {
  type    = string
  default = "16"
}

variable "instance_class" {
  description = "db.t3.micro é elegível ao Free Tier (single-AZ)"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "max_allocated_storage" {
  description = "Limite do autoscaling de storage (0 desativa)"
  type        = number
  default     = 0
}

variable "db_name" {
  type = string
}

variable "username" {
  type = string
}

variable "password" {
  type      = string
  sensitive = true
}

variable "subnet_ids" {
  description = "Subnets privadas do DB subnet group"
  type        = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "multi_az" {
  description = "Multi-AZ (alta disponibilidade, ~2x o custo)"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "skip_final_snapshot" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "storage_type" {
  description = "gp2 é o storage do Free Tier; gp3 pode ter indisponibilidade de capacidade em t4g.micro"
  type        = string
  default     = "gp2"
}
