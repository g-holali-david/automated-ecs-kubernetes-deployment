# ---------- Commun ----------

variable "projet" {
  description = "Prefixe applique aux ressources des deux cibles"
  type        = string
  default     = "boutique"
}

# La reference d'image differe par cible : ECS tire depuis ECR, tandis que
# Minikube ne peut pas s'authentifier aupres d'ECR sans imagePullSecret.
# L'image y est donc chargee localement (minikube image load).

variable "image_ecs" {
  description = "Image applicative pour ECS (depot ECR, tag explicite)"
  type        = string
  default     = "674501463174.dkr.ecr.us-east-1.amazonaws.com/boutique:v7.0.0"
}

variable "image_k8s" {
  description = "Image applicative pour Kubernetes, chargee via minikube image load"
  type        = string
  default     = "web-ipssi:v7.0.0"
}

# Variable pour le déploiement ECS

variable "aws_region" {
  description = "Region AWS (us-east-1 impose par AWS Academy)"
  type        = string
  default     = "us-east-1"
}

variable "lab_role_arn" {
  description = "Execution role des taches ECS. AWS Academy interdit la creation de roles IAM : on reutilise LabRole."
  type        = string
}

variable "ecs_desired_count" {
  description = "Nombre de taches ECS souhaitees"
  type        = number
  default     = 2
}

# Variables pour le deploiement Kubernetes 

variable "kube_config_path" {
  description = "Chemin du kubeconfig"
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Contexte kubectl cible"
  type        = string
  default     = "eval"
}

variable "k8s_replicas" {
  description = "Nombre de replicas du Deployment"
  type        = number
  default     = 3
}

variable "k8s_host" {
  description = "Nom d'hote expose par l'Ingress"
  type        = string
  default     = "boutique.local"
}

variable "kyverno_active" {
  description = "Active le garde-fou Kyverno sur la cible Kubernetes"
  type        = bool
  default     = true
}
