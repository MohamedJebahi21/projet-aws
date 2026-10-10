output "bucket_name" {
  description = "Nom du bucket S3 d'artefacts et reçus"
  value       = var.bucket_name
}

output "bucket_arn" {
  description = "ARN du bucket S3 d'artefacts"
  value       = "arn:aws:s3:::${var.bucket_name}"
}

output "db_secret_s3_key" {
  description = "Clé S3 de l'objet contenant le mot de passe de la DB"
  value       = aws_s3_object.db_secret.key
}

output "app_jar_s3_key" {
  description = "Clé S3 de l'artefact JAR applicatif"
  value       = aws_s3_object.app_jar.key
}
