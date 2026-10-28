# ========================================================
# MODULE STOCKAGE : Bucket S3 Chiffré, Privé, Artefacts Applicatifs
# Conforme aux contraintes de sécurité AWS & SCPs AWS Academy
# ========================================================

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

# 3. Téléversement du paquet applicatif CineTrekker dans S3
resource "aws_s3_object" "app_jar" {
  bucket                 = var.bucket_name
  key                    = "app/cinetrekker.tar.gz"
  source                 = "${path.root}/../../../app/cinetrekker.tar.gz"
  server_side_encryption = "AES256"
  etag                   = fileexists("${path.root}/../../../app/cinetrekker.tar.gz") ? filemd5("${path.root}/../../../app/cinetrekker.tar.gz") : null

  tags = merge(var.tags, {
    Name = "${var.prefix}-cinetrekker-package"
  })

  depends_on = [
    aws_s3_bucket_public_access_block.artifacts,
    aws_s3_bucket_server_side_encryption_configuration.artifacts
  ]
}
