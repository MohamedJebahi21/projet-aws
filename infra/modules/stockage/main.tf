# ========================================================
# MODULE STOCKAGE : Bucket S3 Chiffré, Privé, Artefacts & Secrets
# ========================================================

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# 1. Bucket S3 pour les artefacts de déploiement et les reçus PDF
resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.prefix}-artifacts-${random_id.bucket_suffix.hex}"
  force_destroy = true # Permet le nettoyage propre lors de la destruction complète

  tags = merge(var.tags, {
    Name = "${var.prefix}-artifacts-bucket"
    Tier = "Storage"
  })
}

# 2. Blocage strict de tout accès public (Exigence de sécurité)
resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 3. Chiffrement par défaut au repos côté serveur (SSE-S3 AES-256)
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 4. Stockage sécurisé du secret RDS dans un objet S3 chiffré
# (Exigence : aucun secret en clair dans Git ou user-data, lu via LabInstanceProfile)
resource "aws_s3_object" "db_secret" {
  bucket                 = aws_s3_bucket.artifacts.id
  key                    = "secrets/db_password.txt"
  content                = var.db_password
  server_side_encryption = "AES256"

  tags = merge(var.tags, {
    Name = "${var.prefix}-db-secret-object"
  })
}

# 5. Téléversement de l'artefact applicatif JAR dans S3
resource "aws_s3_object" "app_jar" {
  bucket                 = aws_s3_bucket.artifacts.id
  key                    = "app/bibliotheque-app.jar"
  source                 = "${path.root}/../../../app/target/bibliotheque-app.jar"
  server_side_encryption = "AES256"
  etag                   = fileexists("${path.root}/../../../app/target/bibliotheque-app.jar") ? filemd5("${path.root}/../../../app/target/bibliotheque-app.jar") : null

  tags = merge(var.tags, {
    Name = "${var.prefix}-app-jar-artifact"
  })
}
