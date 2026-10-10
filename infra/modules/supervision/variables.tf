variable "prefix" {
  description = "Préfixe des ressources"
  type        = string
}

variable "asg_name" {
  description = "Nom de l'Auto Scaling Group"
  type        = string
}

variable "alb_arn_suffix" {
  description = "Suffixe ARN de l'ALB"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Suffixe ARN du Target Group"
  type        = string
}

variable "db_instance_id" {
  description = "Identifiant de l'instance RDS"
  type        = string
}

variable "tags" {
  description = "Étiquettes par défaut"
  type        = map(string)
  default     = {}
}
