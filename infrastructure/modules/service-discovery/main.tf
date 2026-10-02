resource "aws_service_discovery_private_dns_namespace" "this" {
  name        = var.namespace_name
  description = "Namespace privado ${var.namespace_name}"
  vpc         = var.vpc_id
  tags        = var.tags
}

# SRV: o ECS (awsvpc) registra IP + porta, que é o que o VPC Link do API Gateway consome
resource "aws_service_discovery_service" "this" {
  name = var.service_name

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.this.id
    routing_policy = "MULTIVALUE"

    dns_records {
      type = "SRV"
      ttl  = 10
    }
  }

  # O ECS remove da lista as tasks que falham no health check do container
  health_check_custom_config {
    failure_threshold = 1
  }

  tags = var.tags
}
