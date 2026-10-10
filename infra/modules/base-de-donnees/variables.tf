variable "prefix" {
  description = "Préfixe des ressources"
  type        = string
}

variable "db_subnet_ids" {
  description = "IDs des sous-réseaux privés pour le subnet group RDS"
  type        = list(string)
}

variable "rds_security_group_id" {
  description = "ID du Security Group pour RDS"
  type        = string
}

variable "db_name" {
  description = "Nom initial de la base de données relationnelle"
  type        = string
  default     = "library"
}

variable "db_username" {
  description = "Nom de l'utilisateur administrateur"
  type        = string
  default     = "dbadmin"
}

variable "tags" {
  description = "Étiquettes par défaut"
  type        = map(string)
  default     = {}
}
