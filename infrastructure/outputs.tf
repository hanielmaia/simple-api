output "api_url" {
  description = "URL pública da API (GET / e GET /connect)"
  value       = local.use_alb ? "http://${module.alb[0].alb_dns_name}" : module.api_gateway[0].invoke_url
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_service_name" {
  value = module.ecs.service_name
}

output "rds_address" {
  value = module.rds.address
}

output "github_deploy_role_arn" {
  description = "Valor da variável AWS_ROLE_ARN do repositório GitHub"
  value       = module.github_oidc.role_arn
}
