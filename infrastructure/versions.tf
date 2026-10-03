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

  # State remoto (bucket criado por infrastructure/bootstrap). Um workspace por ambiente:
  # o state de cada um fica em env:/<workspace>/simple-api/terraform.tfstate
  backend "s3" {
    bucket       = "simple-api-tfstate-705942572148"
    key          = "simple-api/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  # FinOps: toda cobrança fica rastreável por projeto/ambiente
  default_tags {
    tags = local.common_tags
  }
}
