output "bucket_name" {
  description = "Nom du bucket S3 d'artefacts"
  value       = var.bucket_name
}

output "bucket_arn" {
  description = "ARN du bucket S3 d'artefacts"
  value       = "arn:aws:s3:::${var.bucket_name}"
}

output "app_jar_s3_key" {
  description = "Clé S3 de l'archive applicative"
  value       = aws_s3_object.app_jar.key
}
