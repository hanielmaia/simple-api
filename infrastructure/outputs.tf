output "alb_dns_name" {
  description = "URL pública da API (http://<dns>/ e /connect)"
  value       = module.alb.alb_dns_name
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
