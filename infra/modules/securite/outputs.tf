output "alb_security_group_id" {
  description = "Identifiant du Security Group pour ALB"
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "Identifiant du Security Group pour les instances EC2 applicatives"
  value       = aws_security_group.app.id
}
