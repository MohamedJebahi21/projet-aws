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
  description = "Sous-réseaux privés pour l'Auto Scaling Group"
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

variable "db_secret_key" {
  description = "Clé S3 de l'objet contenant le mot de passe de la DB"
  type        = string
}

variable "app_jar_key" {
  description = "Clé S3 de l'artefact JAR applicatif"
  type        = string
}

variable "db_host" {
  description = "Hôte de la base de données RDS"
  type        = string
}

variable "db_port" {
  description = "Port de la base de données RDS"
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "Nom de la base de données"
  type        = string
  default     = "library"
}

variable "db_username" {
  description = "Nom d'utilisateur administrateur"
  type        = string
  default     = "dbadmin"
}

variable "tags" {
  description = "Étiquettes par défaut"
  type        = map(string)
  default     = {}
}
