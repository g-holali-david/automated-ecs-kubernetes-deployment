# ---------- Commun ----------

variable "projet" {
  description = "Prefixe applique aux ressources des deux cibles"
  type        = string
  default     = "boutique"
}

variable "image" {
  description = "Image applicative, taguee explicitement (jamais latest)"
  type        = string
  default     = "nginxdemos/hello:plain-text"
}

# ---------- Cible ECS ----------

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

# ---------- Cible Kubernetes ----------

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
