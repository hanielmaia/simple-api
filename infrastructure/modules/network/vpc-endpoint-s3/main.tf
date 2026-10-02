# Gateway endpoint do S3 é gratuito: o pull das camadas de imagem do ECR deixa de passar (e ser cobrado) pelo NAT
data "aws_region" "current" {}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids
  tags              = var.tags
}
