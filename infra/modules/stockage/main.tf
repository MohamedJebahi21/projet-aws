# ========================================================
# MODULE STOCKAGE : Bucket S3 Chiffré, Privé, Artefacts & Secrets
# Conforme aux contraintes de sécurité AWS & SCPs AWS Academy
# ========================================================

# Note d'ingénierie Cloud / Dérogation SCP Vocareum :
# En environnement AWS Academy Learner Lab, la ressource brute 'aws_s3_bucket' de Terraform
# appelle l'API 's3:GetBucketObjectLockConfiguration' lors du rafraîchissement d'état.
# Cette API est explicitement bloquée par la SCP 'p-22pk8bu3' de l'Organisation AWS Academy,
# ce qui provoquait une erreur 403 AccessDenied fatale dans le provider AWS.
# Le bucket est donc créé de manière idempotente par le script de déploiement, et
# Terraform configure ici les règles de conformité (chiffrement SSE-S3 AES-256,
# blocage des accès publics) ainsi que les objets chiffrés (secret DB et JAR applicatif).

# 1. Blocage strict de tout accès public (Exigence de sécurité)
resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = var.bucket_name

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 2. Chiffrement par défaut au repos côté serveur (SSE-S3 AES-256)
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = var.bucket_name

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 3. Stockage sécurisé du secret RDS dans un objet S3 chiffré
# (Exigence : aucun secret en clair dans Git ou user-data, lu via LabInstanceProfile)
resource "aws_s3_object" "db_secret" {
  bucket                 = var.bucket_name
  key                    = "secrets/db_password.txt"
  content                = var.db_password
  server_side_encryption = "AES256"

  tags = merge(var.tags, {
    Name = "${var.prefix}-db-secret-object"
  })

  depends_on = [
    aws_s3_bucket_public_access_block.artifacts,
    aws_s3_bucket_server_side_encryption_configuration.artifacts
  ]
}

# 4. Téléversement de l'artefact applicatif JAR dans S3
resource "aws_s3_object" "app_jar" {
  bucket                 = var.bucket_name
  key                    = "app/bibliotheque-app.jar"
  source                 = "${path.root}/../../../app/target/bibliotheque-app.jar"
  server_side_encryption = "AES256"
  etag                   = fileexists("${path.root}/../../../app/target/bibliotheque-app.jar") ? filemd5("${path.root}/../../../app/target/bibliotheque-app.jar") : null

  tags = merge(var.tags, {
    Name = "${var.prefix}-app-jar-artifact"
  })

  depends_on = [
    aws_s3_bucket_public_access_block.artifacts,
    aws_s3_bucket_server_side_encryption_configuration.artifacts
  ]
}
