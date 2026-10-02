locals {
  name = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
  }

  # ECS/RDS só em subnets privadas; ALB/NAT nas públicas
  nat_keys = var.nat_per_az ? range(length(var.public_subnet_names)) : [0]
}

data "aws_caller_identity" "current" {}

#==========================================================================
# NETWORK: vpc -> subnets -> igw/nat -> route tables/routes
#==========================================================================
module "vpc" {
  source         = "./modules/network/vpc"
  vpc_cidr_block = var.vpc_cidr_block
  tags           = var.tags_vpc
}

module "subnet_public" {
  source                  = "./modules/network/subnet"
  vpc_id                  = module.vpc.vpc_id
  subnet_name             = var.public_subnet_names
  subnet_cidr             = var.subnet_cidr_blocks_public
  availability_zone       = var.availability_zones_public
  map_public_ip_on_launch = true
  tags                    = var.tags_public_subnet
}

module "subnet_private" {
  source            = "./modules/network/subnet"
  vpc_id            = module.vpc.vpc_id
  subnet_name       = var.private_subnet_names
  subnet_cidr       = var.subnet_cidr_blocks_private
  availability_zone = var.availability_zones_private
  tags              = var.tags_private_subnet
}

locals {
  # subnet_id vem como mapa nome => id; a ordem das listas segue os *_names
  public_subnet_ids  = [for n in var.public_subnet_names : module.subnet_public.subnet_id[n]]
  private_subnet_ids = [for n in var.private_subnet_names : module.subnet_private.subnet_id[n]]
}

module "internet_gateway" {
  source = "./modules/network/internet-gateway"
  vpc_id = module.vpc.vpc_id
  tags   = var.tags_internet_gateway
}

module "nat_gateway" {
  source   = "./modules/network/nat-gateway"
  for_each = toset([for k in local.nat_keys : tostring(k)])

  public_subnet_id = local.public_subnet_ids[tonumber(each.key)]
  tags             = merge(var.tags_vpc, { Name = "${local.name}-nat-${each.key}" })

  depends_on = [module.internet_gateway]
}

module "route_table_public" {
  source     = "./modules/network/route-table"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = local.public_subnet_ids
  azs        = var.availability_zones_public
  tags       = var.tags_rt_public
}

module "route_table_private" {
  source     = "./modules/network/route-table"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = local.private_subnet_ids
  azs        = var.availability_zones_private
  tags       = var.tags_rt_private
}

module "route_public" {
  source   = "./modules/network/route"
  for_each = toset([for i in range(length(local.public_subnet_ids)) : tostring(i)])

  route_table_id = module.route_table_public.route_table_ids[tonumber(each.key)]
  routes_json    = file("${path.module}/config/routes/public.json")
  placeholders   = { "$${IGW_ID}" = module.internet_gateway.internet_gateway_id }
}

module "route_private" {
  source   = "./modules/network/route"
  for_each = toset([for i in range(length(local.private_subnet_ids)) : tostring(i)])

  route_table_id = module.route_table_private.route_table_ids[tonumber(each.key)]
  # Cada subnet privada usa o NAT da sua AZ (ou o NAT único)
  routes_json  = file("${path.module}/config/routes/private.json")
  placeholders = { "$${NAT_GW_ID}" = module.nat_gateway[var.nat_per_az ? each.key : "0"].nat_gateway_id }
}

module "rt_association_public" {
  source          = "./modules/network/route-table-association"
  subnet_ids      = local.public_subnet_ids
  route_table_ids = module.route_table_public.route_table_ids
}

module "rt_association_private" {
  source          = "./modules/network/route-table-association"
  subnet_ids      = local.private_subnet_ids
  route_table_ids = module.route_table_private.route_table_ids
}

#==========================================================================
# SECURITY GROUPS (regras em config/security_rules/*.json)
#==========================================================================
locals {
  sg_rules_alb = jsondecode(replace(
    file("${path.module}/config/security_rules/rules-sg-alb.json"),
    "$${VPC_CIDR}", var.vpc_cidr_block
  ))
  sg_rules_ecs = jsondecode(replace(replace(
    file("${path.module}/config/security_rules/rules-sg-ecs.json"),
    "$${ALB_SG_ID}", module.sg_alb.security_group_id),
    "$${VPC_CIDR}", var.vpc_cidr_block
  ))
  sg_rules_rds = jsondecode(replace(
    file("${path.module}/config/security_rules/rules-sg-rds.json"),
    "$${ECS_SG_ID}", module.sg_ecs.security_group_id
  ))
}

module "sg_alb" {
  source        = "./modules/security/security-group"
  name          = "${local.name}-alb-sg"
  description   = "ALB publico ${local.name}"
  vpc_id        = module.vpc.vpc_id
  ingress_rules = local.sg_rules_alb.ingress
  egress_rules  = local.sg_rules_alb.egress
  tags          = { Name = "${local.name}-alb-sg" }
}

module "sg_ecs" {
  source        = "./modules/security/security-group"
  name          = "${local.name}-ecs-sg"
  description   = "Tasks ECS ${local.name}"
  vpc_id        = module.vpc.vpc_id
  ingress_rules = local.sg_rules_ecs.ingress
  egress_rules  = local.sg_rules_ecs.egress
  tags          = { Name = "${local.name}-ecs-sg" }
}

module "sg_rds" {
  source        = "./modules/security/security-group"
  name          = "${local.name}-rds-sg"
  description   = "RDS ${local.name}"
  vpc_id        = module.vpc.vpc_id
  ingress_rules = local.sg_rules_rds.ingress
  egress_rules  = local.sg_rules_rds.egress
  tags          = { Name = "${local.name}-rds-sg" }
}

#==========================================================================
# ALB -> TARGET GROUP -> LISTENER
#==========================================================================
module "alb" {
  source             = "./modules/network/alb"
  name               = "${local.name}-alb"
  security_group_ids = [module.sg_alb.security_group_id]
  subnet_ids         = local.public_subnet_ids
  tags               = { Name = "${local.name}-alb" }
}

module "target_group" {
  source            = "./modules/network/target-group"
  name              = "${local.name}-tg"
  port              = var.app_port
  vpc_id            = module.vpc.vpc_id
  health_check_path = var.health_check_path
  tags              = { Name = "${local.name}-tg" }
}

module "listener" {
  source            = "./modules/network/listener"
  load_balancer_arn = module.alb.alb_arn
  target_group_arn  = module.target_group.target_group_arn
  port              = 80
  protocol          = "HTTP"
}

#==========================================================================
# ECR
#==========================================================================
module "ecr" {
  source     = "./modules/ecr"
  name       = local.name
  max_images = var.ecr_max_images
}

#==========================================================================
# RDS + PARAMETER STORE (credenciais nunca em tfvars)
#==========================================================================
resource "random_password" "db" {
  length  = 24
  special = false
}

module "rds" {
  source     = "./modules/rds"
  identifier = "${local.name}-db"

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  instance_class        = var.db_instance_class
  multi_az              = var.db_multi_az
  backup_retention_days = var.db_backup_retention_days
  deletion_protection   = var.db_deletion_protection
  skip_final_snapshot   = var.db_skip_final_snapshot

  subnet_ids         = local.private_subnet_ids
  security_group_ids = [module.sg_rds.security_group_id]
  tags               = { Name = "${local.name}-db" }
}

locals {
  ssm_prefix = "/${var.project_name}/${var.environment}"

  # Todas as variáveis DB_* da app via Parameter Store; só a senha é SecureString
  app_parameters = {
    DB_HOST     = { value = module.rds.address, type = "String" }
    DB_PORT     = { value = tostring(module.rds.port), type = "String" }
    DB_DATABASE = { value = module.rds.db_name, type = "String" }
    DB_USER     = { value = var.db_username, type = "String" }
    DB_PASSWORD = { value = random_password.db.result, type = "SecureString" }
  }
}

module "ssm" {
  source   = "./modules/security/parameter-store"
  for_each = local.app_parameters

  name        = "${local.ssm_prefix}/${each.key}"
  description = "${each.key} da ${local.name}"
  type        = each.value.type
  value       = each.value.value
}

#==========================================================================
# IAM (least privilege)
#==========================================================================
data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

# Execution role: puxar imagem, escrever logs (managed policy) + ler APENAS os parâmetros desta app
data "aws_iam_policy_document" "execution_ssm" {
  statement {
    actions   = ["ssm:GetParameters"]
    resources = [for m in module.ssm : m.arn]
  }
}

module "iam_execution" {
  source                  = "./modules/security/iam-role"
  role_name               = "${local.name}-ecs-execution"
  assume_role_policy_json = data.aws_iam_policy_document.ecs_tasks_assume.json
  managed_policy_arns     = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
  attach_policy           = true
  policy_json             = data.aws_iam_policy_document.execution_ssm.json
  tags                    = {}
}

# Task role: a app não chama APIs AWS, então não recebe nenhuma permissão
module "iam_task" {
  source                  = "./modules/security/iam-role"
  role_name               = "${local.name}-ecs-task"
  assume_role_policy_json = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags                    = {}
}

#==========================================================================
# ECS (Fargate) nas subnets privadas
#==========================================================================
module "ecs" {
  source = "./modules/ecs"

  cluster_name    = "${local.name}-cluster"
  service_name    = local.name
  region          = var.region
  container_name  = "simple-api"
  container_image = "${module.ecr.repository_url}:${var.container_image_tag}"
  container_port  = var.app_port

  task_cpu      = var.task_cpu
  task_memory   = var.task_memory
  desired_count = var.desired_count

  execution_role_arn = module.iam_execution.role_arn
  task_role_arn      = module.iam_task.role_arn

  subnet_ids         = local.private_subnet_ids
  security_group_ids = [module.sg_ecs.security_group_id]
  assign_public_ip   = false
  target_group_arn   = module.target_group.target_group_arn

  environment_variables = [
    { name = "API_PORT", value = tostring(var.app_port) },
    { name = "DB_SSL", value = "true" },
  ]
  secrets = [for k, m in module.ssm : { name = k, valueFrom = m.arn }]

  log_retention_in_days = var.log_retention_in_days

  depends_on = [module.listener]
}

#==========================================================================
# CI/CD: role OIDC do GitHub Actions (sem chaves estáticas)
#==========================================================================
module "github_oidc" {
  source = "./modules/security/github-oidc"

  role_name          = "${local.name}-github-deploy"
  subject_prefixes   = concat(["repo:${var.github_repo}"], var.github_oidc_extra_subject_prefixes)
  branch             = var.github_branch
  create_provider    = var.create_github_oidc_provider
  ecr_repository_arn = module.ecr.repository_arn
  ecs_service_arn    = "arn:aws:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:service/${module.ecs.cluster_name}/${module.ecs.service_name}"
  pass_role_arns     = [module.iam_execution.role_arn, module.iam_task.role_arn]
}
