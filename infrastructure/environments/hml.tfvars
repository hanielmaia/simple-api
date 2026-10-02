#==========================================================================
# PROJECT CONFIGURATION
#==========================================================================
project_name = "simple-api"
environment  = "hml"
region       = "us-east-1"

#==========================================================================
# NETWORK CONFIGURATION
#==========================================================================
# VPC Configuration
vpc_cidr_block = "10.110.0.0/16"

# Subnets
availability_zones_public  = ["us-east-1a", "us-east-1b"]
availability_zones_private = ["us-east-1a", "us-east-1b"]
public_subnet_names        = ["public-subnet-1a", "public-subnet-1b"]
private_subnet_names       = ["private-subnet-1a", "private-subnet-1b"]
subnet_cidr_blocks_public  = ["10.110.1.0/24", "10.110.2.0/24"]
subnet_cidr_blocks_private = ["10.110.11.0/24", "10.110.12.0/24"]

# Network Tags
tags_vpc = {
  Name = "simple-api-vpc-hml"
  Type = "vpc"
}

tags_public_subnet = {
  Name = "simple-api-public-subnet-hml"
  Type = "public"
}

tags_private_subnet = {
  Name = "simple-api-private-subnet-hml"
  Type = "private"
}

tags_internet_gateway = {
  Name = "simple-api-igw-hml"
  Type = "internet-gateway"
}

tags_rt_public = {
  Name = "simple-api-public-rt-hml"
  Type = "public"
}

tags_rt_private = {
  Name = "simple-api-private-rt-hml"
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
desired_count         = 1
log_retention_in_days = 14
ecr_max_images        = 10

# FinOps: NAT único fora de prod (1 NAT por AZ só em prod)
nat_per_az = false

#==========================================================================
# RDS (a senha é gerada pelo Terraform e guardada no Parameter Store)
#==========================================================================
db_name                  = "appdb"
db_username              = "appuser"
db_instance_class        = "db.t3.micro"
db_multi_az              = false
db_backup_retention_days = 1
db_deletion_protection   = false
db_skip_final_snapshot   = true

# O provider OIDC é único por conta e já é criado pelo ambiente dev
create_github_oidc_provider = false

#==========================================================================
# EXPOSIÇÃO, RESILIÊNCIA E FINOPS
#==========================================================================
expose_mode              = "apigw"
use_spot                 = true
autoscaling_max_capacity = 0
schedule_enabled         = true
# alert_email            = "voce@exemplo.com"  # habilita alarmes CloudWatch e Budget
