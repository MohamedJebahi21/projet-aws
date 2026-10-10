variable "aws_region" {
  description = "Région AWS unique imposée par le Learner Lab"
  type        = string
  default     = "us-east-1"
}

variable "prefix" {
  description = "Préfixe normalisé pour toutes les ressources du groupe"
  type        = string
  default     = "biblio-dev"
}

variable "environment" {
  description = "Nom de l'environnement"
  type        = string
  default     = "dev"
}

variable "db_name" {
  description = "Nom de la base relationnelle PostgreSQL"
  type        = string
  default     = "library"
}

variable "db_username" {
  description = "Utilisateur administrateur PostgreSQL"
  type        = string
  default     = "dbadmin"
}
