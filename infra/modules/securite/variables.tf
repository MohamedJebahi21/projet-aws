variable "prefix" {
  description = "Préfixe des ressources"
  type        = string
}

variable "vpc_id" {
  description = "ID du VPC"
  type        = string
}

variable "tags" {
  description = "Étiquettes par défaut"
  type        = map(string)
  default     = {}
}
