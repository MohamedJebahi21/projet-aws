output "alb_dns_name" {
  description = "Nom DNS public de l'Application Load Balancer"
  value       = module.calcul.alb_dns_name
}

output "application_url" {
  description = "URL publique d'accès à l'application web"
  value       = "http://${module.calcul.alb_dns_name}"
}

output "healthcheck_url" {
  description = "URL du contrôle de santé ALB"
  value       = "http://${module.calcul.alb_dns_name}/health"
}

output "s3_artifacts_bucket" {
  description = "Nom du bucket S3 d'artefacts"
  value       = module.stockage.bucket_name
}

output "nat_public_ip" {
  description = "IP publique de l'instance NAT"
  value       = module.reseau.nat_public_ip
}
