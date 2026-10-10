output "alb_security_group_id" {
  description = "ID du Security Group de l'ALB"
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "ID du Security Group de la couche applicative"
  value       = aws_security_group.app.id
}

output "rds_security_group_id" {
  description = "ID du Security Group de la base de données RDS"
  value       = aws_security_group.rds.id
}
