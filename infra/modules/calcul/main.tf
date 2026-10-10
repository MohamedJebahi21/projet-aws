# ========================================================
# MODULE CALCUL : ALB Public, Launch Template & Auto Scaling Group Multi-AZ
# ========================================================

# 1. Image AMI Amazon Linux 2023
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 2. Application Load Balancer (ALB) - Point d'entrée public unique
resource "aws_lb" "main" {
  name               = "${var.prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = merge(var.tags, {
    Name = "${var.prefix}-alb"
    Tier = "LoadBalancer"
  })
}

# 3. Target Group avec Contrôle de Santé (Route /health)
resource "aws_lb_target_group" "app" {
  name                 = "${var.prefix}-tg"
  port                 = 8080
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "instance"
  deregistration_delay = 30 # Accélère le retrait d'une instance défaillante ou lors des tests

  health_check {
    enabled             = true
    path                = "/health"
    port                = "8080"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = merge(var.tags, {
    Name = "${var.prefix}-tg"
  })
}

# 4. Listener HTTP port 80 de l'ALB
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# 5. Launch Template pour les instances EC2 privées
resource "aws_launch_template" "app" {
  name_prefix   = "${var.prefix}-lt-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"

  # Rôle IAM imposé par AWS Academy Learner Lab
  iam_instance_profile {
    name = "LabInstanceProfile"
  }

  vpc_security_group_ids = [var.app_security_group_id]

  # Configuration du volume racine EBS gp3
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  # User Data automatisé (Provisionnement complet sans intervention manuelle)
  user_data = base64encode(<<-EOF
              #!/bin/bash
              set -ex
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

              echo "=== Demarrage de l'initialisation de l'instance ==="

              # 1. Mise a jour et installation de Java 17 headless + agent CloudWatch
              dnf update -y
              dnf install -y java-17-amazon-corretto-headless amazon-cloudwatch-agent

              # 2. Preparation des repertoires applicatifs
              mkdir -p /opt/app /etc/library

              # 3. Recuperation securisee du secret DB depuis l'objet S3 chiffre
              echo "Recuperation du mot de passe RDS depuis S3..."
              DB_SECRET_VAL=$(aws s3 cp s3://${var.bucket_name}/${var.db_secret_key} -)

              cat << ENVFILE > /etc/library/app.env
              PORT=8080
              DB_HOST=${var.db_host}
              DB_PORT=${var.db_port}
              DB_NAME=${var.db_name}
              DB_USER=${var.db_username}
              DB_PASSWORD=$DB_SECRET_VAL
              S3_BUCKET_NAME=${var.bucket_name}
              AWS_REGION=us-east-1
              ENVFILE
              chmod 600 /etc/library/app.env

              # 4. Recuperation de l'artefact applicatif JAR depuis S3
              echo "Recuperation du package JAR depuis S3..."
              aws s3 cp s3://${var.bucket_name}/${var.app_jar_key} /opt/app/bibliotheque-app.jar

              # 5. Creation du service systemd
              cat << SERVICEFILE > /etc/systemd/system/bibliotheque.service
              [Unit]
              Description=Application Web Bibliotheque Universitaire 3-Tiers
              After=network.target

              [Service]
              Type=simple
              User=ec2-user
              WorkingDirectory=/opt/app
              EnvironmentFile=/etc/library/app.env
              ExecStart=/usr/bin/java -XX:+UseContainerSupport -XX:MaxRAMPercentage=70.0 -jar /opt/app/bibliotheque-app.jar
              Restart=always
              RestartSec=10
              StandardOutput=journal
              StandardError=journal

              [Install]
              WantedBy=multi-user.target
              SERVICEFILE

              chown -R ec2-user:ec2-user /opt/app /etc/library
              systemctl daemon-reload
              systemctl enable bibliotheque.service
              systemctl start bibliotheque.service

              # 6. Configuration et demarrage de l'agent CloudWatch
              cat << CWCONFIG > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
              {
                "agent": {
                  "metrics_collection_interval": 60,
                  "run_as_user": "root"
                },
                "logs": {
                  "logs_collected": {
                    "files": {
                      "collect_list": [
                        {
                          "file_path": "/var/log/user-data.log",
                          "log_group_name": "/aws/ec2/${var.prefix}-app",
                          "log_stream_name": "{instance_id}/user-data"
                        }
                      ]
                    }
                  }
                }
              }
              CWCONFIG

              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
                -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

              echo "=== Fin de l'initialisation de l'instance avec succes ==="
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.prefix}-app-instance"
      Tier = "Application"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.prefix}-launch-template"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# 6. Auto Scaling Group Multi-AZ en sous-réseaux privés (Minimum 2 instances)
resource "aws_autoscaling_group" "app" {
  name_prefix         = "${var.prefix}-asg-"
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2
  vpc_zone_identifier = var.private_subnet_ids

  target_group_arns         = [aws_lb_target_group.app.arn]
  health_check_type         = "ELB" # Contrôle de santé basé sur l'ALB
  health_check_grace_period = 180

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Déploiement progressif sans interruption de service (Rolling update)
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 120
    }
    triggers = ["tag"]
  }

  tag {
    key                 = "Name"
    value               = "${var.prefix}-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Tier"
    value               = "Application"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
