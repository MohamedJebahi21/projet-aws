# ========================================================
# MODULE SUPERVISION : CloudWatch Logs, Dashboard & Alarmes
# Observabilité complète et diagnostic immédiat des pannes
# ========================================================

# 1. Groupe de Logs CloudWatch (Rétention courte de 1 jour pour maîtriser les coûts)
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/ec2/${var.prefix}-app"
  retention_in_days = 1

  tags = merge(var.tags, {
    Name = "${var.prefix}-cloudwatch-log-group"
  })
}

# 2. Alarme 1 : Cibles Non Saines sur l'ALB (UnHealthyHostCount >= 1)
# Déclenchable lors de l'épreuve de panne ou injection d'incident
resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  alarm_name          = "${var.prefix}-alarm-unhealthy-hosts"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "Alerte : Au moins une instance applicative echoue au controle de sante ALB"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = var.target_group_arn_suffix
    LoadBalancer = var.alb_arn_suffix
  }

  tags = merge(var.tags, {
    Name = "${var.prefix}-alarm-unhealthy-hosts"
  })
}

# 3. Alarme 2 : Utilisation CPU Élevée sur l'ASG (> 70%)
# Déclenchable lors du test de charge (Livrable 7)
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.prefix}-alarm-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Alerte : La charge CPU moyenne du groupe Auto Scaling depasse 70%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }

  tags = merge(var.tags, {
    Name = "${var.prefix}-alarm-high-cpu"
  })
}

# 4. Tableau de Bord Unifié CloudWatch (Dashboard)
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.prefix}-supervision-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Santé des Cibles ALB (Healthy vs Unhealthy)"
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", var.target_group_arn_suffix, "LoadBalancer", var.alb_arn_suffix, { color = "#2ca02c" }],
            [".", "UnHealthyHostCount", ".", ".", ".", ".", { color = "#d62728" }]
          ]
          period = 60
          region = "us-east-1"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Utilisation CPU Auto Scaling (%)"
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.asg_name, { color = "#1f77b4" }]
          ]
          period = 60
          region = "us-east-1"
          yAxis = {
            left = { min = 0, max = 100 }
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "Nombre de Requêtes & Erreurs HTTP ALB"
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", color = "#17becf" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { stat = "Sum", color = "#e377c2" }]
          ]
          period = 60
          region = "us-east-1"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "Connexions Actives RDS PostgreSQL"
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.db_instance_id, { stat = "Average", color = "#ff7f0e" }]
          ]
          period = 60
          region = "us-east-1"
        }
      }
    ]
  })
}
