variable "prefix" {
  description = "Préfixe des ressources"
  type        = string
}

variable "bucket_name" {
  description = "Nom du bucket S3 (isolé et conforme aux SCPs AWS Academy)"
  type        = string
}

variable "db_password" {
  description = "Mot de passe de la base de données à stocker de manière chiffrée"
  type        = string
  sensitive   = true
}

variable "db_host" {
  description = "Hôte RDS (endpoint) pour le fichier de configuration sécurisé"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Étiquettes par défaut"
  type        = map(string)
  default     = {}
}
