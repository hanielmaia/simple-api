variable "namespace_name" { type = string }
variable "service_name" { type = string }
variable "vpc_id" { type = string }

variable "tags" {
  type    = map(string)
  default = {}
}
