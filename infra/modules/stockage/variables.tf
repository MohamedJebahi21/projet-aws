variable "prefix" {
  description = "Préfixe des ressources pour l'identification et le nettoyage"
  type        = string
}

variable "bucket_name" {
  description = "Nom unique global du bucket S3 d'artefacts"
  type        = string
}

variable "tags" {
  description = "Étiquettes par défaut appliquées à toutes les ressources"
  type        = map(string)
  default     = {}
}
