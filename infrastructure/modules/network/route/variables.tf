variable "route_table_id" {
  description = "ID da route table alvo."
  type        = string
}

variable "routes_json" {
  description = "JSON com rotas (mapa nome_logico => objeto)."
  type        = string
}

variable "placeholders" {
  description = "Mapa placeholder => valor (ex: { \"$${NAT_GW_ID}\" = \"nat-123\" }) aplicado aos alvos da rota"
  type        = map(string)
  default     = {}
}
