output "vpc_id" {
  description = "ID du VPC créé"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Liste des IDs des sous-réseaux publics (ALB)"
  value       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

output "private_subnet_ids" {
  description = "Liste des IDs des sous-réseaux privés applicatifs (EC2 ASG)"
  value       = [aws_subnet.private_1.id, aws_subnet.private_2.id]
}

output "db_subnet_ids" {
  description = "Liste des IDs des sous-réseaux privés pour RDS"
  value       = [aws_subnet.db_1.id, aws_subnet.db_2.id]
}

output "nat_instance_id" {
  description = "ID de l'instance NAT"
  value       = aws_instance.nat.id
}

output "nat_public_ip" {
  description = "IP publique de l'instance NAT"
  value       = aws_instance.nat.public_ip
}
