variable "prefix" {
  description = "Préfixe des ressources"
  type        = string
}

variable "vpc_id" {
  description = "ID du VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "Sous-réseaux publics pour l'ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Sous-réseaux privés pour l'instance applicative / Auto Scaling Group"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "ID du Security Group pour l'ALB"
  type        = string
}

variable "app_security_group_id" {
  description = "ID du Security Group pour les instances applicatives"
  type        = string
}

variable "bucket_name" {
  description = "Nom du bucket S3 d'artefacts"
  type        = string
}

variable "app_jar_key" {
  description = "Clé S3 de l'archive applicative"
  type        = string
}

variable "tags" {
  description = "Étiquettes par défaut"
  type        = map(string)
  default     = {}
}
