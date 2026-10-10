# ========================================================
# ORCHESTRATION INFRASTRUCTURE TERRAFORM - ENVIRONNEMENT DEV
# Déploiement complet 3-tiers AWS Free Tier / AWS Academy
# ========================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
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
    Project     = "Bibliotheque-AWS-3Tiers"
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

# 3. Module Base de Données (Amazon RDS PostgreSQL Managé)
module "base_de_donnees" {
  source                = "../../modules/base-de-donnees"
  prefix                = var.prefix
  db_subnet_ids         = module.reseau.db_subnet_ids
  rds_security_group_id = module.securite.rds_security_group_id
  db_name               = var.db_name
  db_username           = var.db_username
  tags                  = local.default_tags
}

# 4. Module Stockage (Bucket S3 Chiffré, Artefacts & Secret DB)
module "stockage" {
  source      = "../../modules/stockage"
  prefix      = var.prefix
  bucket_name = local.bucket_name
  db_password = module.base_de_donnees.db_password
  db_host     = module.base_de_donnees.db_address
  tags        = local.default_tags
}

# 5. Module Calcul (ALB Public, Launch Template & Auto Scaling Group)
module "calcul" {
  source                = "../../modules/calcul"
  prefix                = var.prefix
  vpc_id                = module.reseau.vpc_id
  public_subnet_ids     = module.reseau.public_subnet_ids
  private_subnet_ids    = module.reseau.private_subnet_ids
  alb_security_group_id = module.securite.alb_security_group_id
  app_security_group_id = module.securite.app_security_group_id
  bucket_name           = module.stockage.bucket_name
  db_secret_key         = module.stockage.db_secret_s3_key
  app_jar_key           = module.stockage.app_jar_s3_key
  db_host               = module.base_de_donnees.db_address
  db_port               = module.base_de_donnees.db_port
  db_name               = module.base_de_donnees.db_name
  db_username           = module.base_de_donnees.db_username
  tags                  = local.default_tags

  depends_on = [
    module.stockage,
    module.base_de_donnees,
    module.reseau
  ]
}

# 6. Module Supervision (CloudWatch Logs, Dashboard & Alarmes)
module "supervision" {
  source                  = "../../modules/supervision"
  prefix                  = var.prefix
  asg_name                = module.calcul.asg_name
  alb_arn_suffix          = module.calcul.alb_arn_suffix
  target_group_arn_suffix = module.calcul.target_group_arn_suffix
  db_instance_id          = module.base_de_donnees.db_instance_id
  tags                    = local.default_tags
}
