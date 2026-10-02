variable "name" {
  description = "Nome do repositório ECR"
  type        = string
}

variable "max_images" {
  description = "Quantidade de imagens mantidas (lifecycle)"
  type        = number
  default     = 10
}

variable "force_delete" {
  description = "Permite destruir o repositório mesmo com imagens"
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
