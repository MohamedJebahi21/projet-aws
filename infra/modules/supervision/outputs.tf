output "dashboard_name" {
  description = "Nom du tableau de bord CloudWatch"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "unhealthy_alarm_arn" {
  description = "ARN de l'alarme cibles non saines"
  value       = aws_cloudwatch_metric_alarm.unhealthy_targets.arn
}

output "high_cpu_alarm_arn" {
  description = "ARN de l'alarme CPU élevé"
  value       = aws_cloudwatch_metric_alarm.high_cpu.arn
}
