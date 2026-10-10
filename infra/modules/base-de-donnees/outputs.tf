output "db_instance_id" {
  description = "ID de l'instance RDS"
  value       = aws_db_instance.postgres.id
}

output "db_endpoint" {
  description = "Endpoint de connexion (host:port)"
  value       = aws_db_instance.postgres.endpoint
}

output "db_address" {
  description = "Adresse d'hôte DNS privé de RDS"
  value       = aws_db_instance.postgres.address
}

output "db_port" {
  description = "Port d'écoute PostgreSQL"
  value       = aws_db_instance.postgres.port
}

output "db_name" {
  description = "Nom de la base de données"
  value       = aws_db_instance.postgres.db_name
}

output "db_username" {
  description = "Utilisateur administrateur de la base"
  value       = aws_db_instance.postgres.username
}

output "db_password" {
  description = "Mot de passe généré aléatoirement"
  value       = random_password.db_password.result
  sensitive   = true
}
