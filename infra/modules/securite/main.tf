# ========================================================
# MODULE SÉCURITÉ : Groupes de Sécurité Chaînés par Référence
# Moindre privilège strict : Aucune administration sur 0.0.0.0/0
# ========================================================

# 1. Groupe de Sécurité pour l'Application Load Balancer (ALB)
resource "aws_security_group" "alb" {
  name        = "${var.prefix}-alb-sg"
  description = "Controle acces public pour Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.prefix}-alb-sg"
    Tier = "Public-ALB"
  })
}

resource "aws_security_group_rule" "alb_ingress_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Acces Web public HTTP"
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_egress_to_app" {
  type                     = "egress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  description              = "Acheminement strict vers le groupe applicatif EC2"
  security_group_id        = aws_security_group.alb.id
}

# 2. Groupe de Sécurité Applicatif (Instances EC2 privées ASG)
resource "aws_security_group" "app" {
  name        = "${var.prefix}-app-sg"
  description = "Controle acces prive pour la couche applicative EC2"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.prefix}-app-sg"
    Tier = "Private-App"
  })
}

resource "aws_security_group_rule" "app_ingress_from_alb" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  description              = "Trafic autorise uniquement depuis ALB"
  security_group_id        = aws_security_group.app.id
}

resource "aws_security_group_rule" "app_egress_to_rds" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.rds.id
  description              = "Acces PostgreSQL vers RDS"
  security_group_id        = aws_security_group.app.id
}

resource "aws_security_group_rule" "app_egress_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Sortie HTTPS vers S3 Endpoint et services AWS"
  security_group_id = aws_security_group.app.id
}

resource "aws_security_group_rule" "app_egress_dns_udp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Resolution DNS interne Amazon"
  security_group_id = aws_security_group.app.id
}

resource "aws_security_group_rule" "app_egress_dns_tcp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Resolution DNS TCP"
  security_group_id = aws_security_group.app.id
}

resource "aws_security_group_rule" "app_egress_http_pkg" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Depots de paquets Linux via NAT"
  security_group_id = aws_security_group.app.id
}

# 3. Groupe de Sécurité Base de Données (Amazon RDS PostgreSQL)
resource "aws_security_group" "rds" {
  name        = "${var.prefix}-rds-sg"
  description = "Controle acces strictement prive pour base de donnees RDS"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.prefix}-rds-sg"
    Tier = "Private-Database"
  })
}

resource "aws_security_group_rule" "rds_ingress_from_app" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  description              = "Connexion PostgreSQL autorisee depuis instances applicatives"
  security_group_id        = aws_security_group.rds.id
}
