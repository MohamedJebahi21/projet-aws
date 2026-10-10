variable "prefix" {
  description = "Préfixe des ressources pour l'identification et le nettoyage"
  type        = string
}

variable "aws_region" {
  description = "Région AWS imposée (us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "Bloc CIDR du VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_1_cidr" {
  description = "CIDR sous-réseau public AZ 1"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  description = "CIDR sous-réseau public AZ 2"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_1_cidr" {
  description = "CIDR sous-réseau privé applicatif AZ 1"
  type        = string
  default     = "10.0.11.0/24"
}

variable "private_subnet_2_cidr" {
  description = "CIDR sous-réseau privé applicatif AZ 2"
  type        = string
  default     = "10.0.12.0/24"
}

variable "db_subnet_1_cidr" {
  description = "CIDR sous-réseau privé base de données AZ 1"
  type        = string
  default     = "10.0.21.0/24"
}

variable "db_subnet_2_cidr" {
  description = "CIDR sous-réseau privé base de données AZ 2"
  type        = string
  default     = "10.0.22.0/24"
}

variable "tags" {
  description = "Étiquettes par défaut appliquées à toutes les ressources"
  type        = map(string)
  default     = {}
}
