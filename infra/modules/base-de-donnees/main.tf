# ========================================================
# MODULE BASE DE DONNÉES : Amazon RDS PostgreSQL Managé
# Isolation stricte en sous-réseau privé, chiffrement, sauvegardes
# ========================================================

# 1. Génération aléatoire d'un mot de passe fort (évite tout secret en dur)
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# 2. Groupe de sous-réseaux privés pour RDS (Multi-AZ de subnet)
resource "aws_db_subnet_group" "main" {
  name        = "${var.prefix}-db-subnet-group"
  subnet_ids  = var.db_subnet_ids
  description = "Groupe de sous-reseaux prives pour RDS PostgreSQL"

  tags = merge(var.tags, {
    Name = "${var.prefix}-db-subnet-group"
  })
}

# 3. Instance de Base de Données RDS PostgreSQL
resource "aws_db_instance" "postgres" {
  identifier        = "${var.prefix}-postgres-db"
  engine            = "postgres"
  engine_version    = "15.8"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_security_group_id]

  # Sécurité : Inaccessible depuis Internet
  publicly_accessible = false
  storage_encrypted   = true

  # Sauvegardes automatisées (Livrable 5)
  backup_retention_period   = 1
  backup_window             = "03:00-04:00"
  maintenance_window        = "Mon:04:30-Mon:05:30"
  auto_minor_version_upgrade = true

  # Décision d'architecture justifiée : Multi-AZ désactivé pour respecter le budget de 50$
  multi_az = false

  # Destruction propre en fin de séance / démonstration
  skip_final_snapshot = true
  deletion_protection = false

  tags = merge(var.tags, {
    Name = "${var.prefix}-postgres-db"
    Tier = "Database"
  })
}
