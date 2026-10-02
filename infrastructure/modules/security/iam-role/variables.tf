variable "role_name" { type = string }
variable "assume_role_policy_json" { type = string }
variable "tags" { type = map(string) }

variable "policy_json" {
  description = "Policy inline customizada (null = nenhuma)"
  type        = string
  default     = null
}

variable "managed_policy_arns" {
  description = "ARNs de managed policies a anexar"
  type        = list(string)
  default     = []
}

variable "attach_policy" {
  description = "Cria e anexa a policy inline (policy_json). Flag separada porque policy_json pode ser desconhecido no plan"
  type        = bool
  default     = false
}
