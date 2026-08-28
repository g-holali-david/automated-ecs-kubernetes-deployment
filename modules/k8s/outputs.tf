output "namespace" {
  description = "Namespace de deploiement"
  value       = kubernetes_namespace_v1.app.metadata[0].name
}

output "service" {
  description = "Service exposant les pods"
  value       = kubernetes_service_v1.app.metadata[0].name
}

output "host" {
  description = "Nom d'hote servi par l'Ingress"
  value       = kubernetes_ingress_v1.app.spec[0].rule[0].host
}

output "replicas" {
  description = "Replicas demandes (le HPA peut faire varier ce nombre)"
  value       = kubernetes_deployment_v1.app.spec[0].replicas
}
