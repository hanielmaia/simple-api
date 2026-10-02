terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # State local por padrão (um workspace por ambiente: terraform workspace select -or-create dev).
  # Para state remoto, descomente e informe um bucket S3 existente:
  # backend "s3" {
  #   bucket       = "<bucket>"
  #   key          = "simple-api/terraform.tfstate"
  #   region       = "us-east-1"
  #   use_lockfile = true
  #   encrypt      = true
  # }
}

provider "aws" {
  region = var.region

  # FinOps: toda cobrança fica rastreável por projeto/ambiente
  default_tags {
    tags = local.common_tags
  }
}
