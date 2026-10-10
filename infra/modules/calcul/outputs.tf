output "alb_dns_name" {
  description = "Nom de domaine DNS public de l'Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN de l'ALB"
  value       = aws_lb.main.arn
}

output "alb_arn_suffix" {
  description = "Suffixe ARN de l'ALB pour les métriques CloudWatch"
  value       = aws_lb.main.arn_suffix
}

output "target_group_arn" {
  description = "ARN du Target Group"
  value       = aws_lb_target_group.app.arn
}

output "target_group_arn_suffix" {
  description = "Suffixe ARN du Target Group pour les métriques CloudWatch"
  value       = aws_lb_target_group.app.arn_suffix
}

output "asg_name" {
  description = "Nom de l'Auto Scaling Group"
  value       = aws_autoscaling_group.app.name
}

output "launch_template_id" {
  description = "ID du Launch Template"
  value       = aws_launch_template.app.id
}
