#==========================================================================
# PROJECT CONFIGURATION
#==========================================================================
project_name = "simple-api"
environment  = "prod"
region       = "us-east-1"

#==========================================================================
# NETWORK CONFIGURATION
#==========================================================================
# VPC Configuration
vpc_cidr_block = "10.120.0.0/16"

# Subnets
availability_zones_public  = ["us-east-1a", "us-east-1b"]
availability_zones_private = ["us-east-1a", "us-east-1b"]
public_subnet_names        = ["public-subnet-1a", "public-subnet-1b"]
private_subnet_names       = ["private-subnet-1a", "private-subnet-1b"]
subnet_cidr_blocks_public  = ["10.120.1.0/24", "10.120.2.0/24"]
subnet_cidr_blocks_private = ["10.120.11.0/24", "10.120.12.0/24"]

# Network Tags
tags_vpc = {
  Name = "simple-api-vpc-prod"
  Type = "vpc"
}

tags_public_subnet = {
  Name = "simple-api-public-subnet-prod"
  Type = "public"
}

tags_private_subnet = {
  Name = "simple-api-private-subnet-prod"
  Type = "private"
}

tags_internet_gateway = {
  Name = "simple-api-igw-prod"
  Type = "internet-gateway"
}

tags_rt_public = {
  Name = "simple-api-public-rt-prod"
  Type = "public"
}

tags_rt_private = {
  Name = "simple-api-private-rt-prod"
  Type = "private"
}

#==========================================================================
# APPLICATION / ECS
#==========================================================================
owner                 = "haniel"
app_port              = 3000
health_check_path     = "/"
container_image_tag   = "bootstrap"
task_cpu              = 256
task_memory           = 512
desired_count         = 2
log_retention_in_days = 14
ecr_max_images        = 10

# FinOps: NAT único fora de prod (1 NAT por AZ só em prod)
nat_per_az = true

#==========================================================================
# RDS (a senha é gerada pelo Terraform e guardada no Parameter Store)
#==========================================================================
db_name                     = "appdb"
db_username                 = "appuser"
db_instance_class           = "db.t3.micro"
db_multi_az                 = true
db_backup_retention_days    = 7
db_deletion_protection      = true
db_skip_final_snapshot      = false
create_github_oidc_provider = false

#==========================================================================
# EXPOSIÇÃO, RESILIÊNCIA E FINOPS
#==========================================================================
expose_mode              = "alb"
use_spot                 = false
autoscaling_max_capacity = 4
schedule_enabled         = false
# alert_email            = "voce@exemplo.com"  # habilita alarmes CloudWatch e Budget
