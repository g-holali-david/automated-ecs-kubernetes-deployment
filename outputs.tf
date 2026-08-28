# ---------- Cible ECS ----------

output "ecs_url" {
  description = "Adresse publique de l'application sur ECS"
  value       = "http://${module.ecs.alb_dns_name}"
}

output "ecs_ecr_repository" {
  description = "Depot ECR"
  value       = module.ecs.ecr_repository_url
}

output "ecs_taches" {
  description = "Nombre de taches Fargate"
  value       = module.ecs.desired_count
}

output "ecs_cluster_name" {
  description = "Nom du cluster ECS"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "Nom du service ECS"
  value       = module.ecs.service_name
}

# ---------- Cible Kubernetes ----------

output "k8s_url" {
  description = "Adresse de l'application sur Kubernetes (via Ingress)"
  value       = "http://${module.k8s.host}"
}

output "k8s_namespace" {
  description = "Namespace de deploiement"
  value       = module.k8s.namespace
}

output "k8s_replicas" {
  description = "Replicas demandes (le HPA peut faire varier ce nombre)"
  value       = module.k8s.replicas
}
