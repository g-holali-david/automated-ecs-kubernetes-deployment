output "ecr_repository_url" {
  description = "URL du depot ECR pour docker tag / push"
  value       = aws_ecr_repository.app.repository_url
}

output "alb_dns_name" {
  description = "Adresse publique de l'application"
  value       = aws_lb.app.dns_name
}

output "cluster_name" {
  description = "Nom du cluster ECS"
  value       = aws_ecs_cluster.app.name
}

output "service_name" {
  description = "Nom du service ECS"
  value       = aws_ecs_service.app.name
}

output "desired_count" {
  description = "Nombre de taches demandees"
  value       = aws_ecs_service.app.desired_count
}
