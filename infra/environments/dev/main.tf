# ========================================================
# ORCHESTRATION INFRASTRUCTURE TERRAFORM - ENVIRONNEMENT DEV
# Déploiement socle réseau multi-AZ, sécurité, calcul et NAT (L1-L3)
# ========================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.default_tags
  }
}

data "aws_caller_identity" "current" {}

locals {
  bucket_name = "${var.prefix}-artifacts-${data.aws_caller_identity.current.account_id}"
  default_tags = {
    Project     = "CineTrekker-AWS-3Tiers"
    Module      = "ING-4-CIM"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Prefix      = var.prefix
  }
}

# 1. Module Réseau (VPC Multi-AZ, sous-réseaux, NAT, S3 Endpoint)
module "reseau" {
  source     = "../../modules/reseau"
  prefix     = var.prefix
  aws_region = var.aws_region
  tags       = local.default_tags
}

# 2. Module Sécurité (Security Groups chaînés par référence)
module "securite" {
  source = "../../modules/securite"
  prefix = var.prefix
  vpc_id = module.reseau.vpc_id
  tags   = local.default_tags
}

# 3. Module Stockage (Bucket S3 Chiffré pour Artefacts)
module "stockage" {
  source      = "../../modules/stockage"
  prefix      = var.prefix
  bucket_name = local.bucket_name
  tags        = local.default_tags
}

# 4. Module Calcul (ALB Public, Launch Template & Auto Scaling Group)
module "calcul" {
  source                = "../../modules/calcul"
  prefix                = var.prefix
  vpc_id                = module.reseau.vpc_id
  public_subnet_ids     = module.reseau.public_subnet_ids
  private_subnet_ids    = module.reseau.private_subnet_ids
  alb_security_group_id = module.securite.alb_security_group_id
  app_security_group_id = module.securite.app_security_group_id
  bucket_name           = module.stockage.bucket_name
  app_jar_key           = module.stockage.app_jar_s3_key
  tags                  = local.default_tags

  depends_on = [
    module.stockage,
    module.reseau
  ]
}
