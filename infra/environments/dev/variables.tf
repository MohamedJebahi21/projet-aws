variable "aws_region" {
  description = "Région AWS unique imposée par le Learner Lab"
  type        = string
  default     = "us-east-1"
}

variable "prefix" {
  description = "Préfixe normalisé pour toutes les ressources du groupe"
  type        = string
  default     = "cinetrekker-dev"
}

variable "environment" {
  description = "Nom de l'environnement"
  type        = string
  default     = "dev"
}
