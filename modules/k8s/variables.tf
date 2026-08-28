variable "projet" {
  description = "Prefixe des ressources"
  type        = string
}

variable "image" {
  description = "Image applicative taguee"
  type        = string
}

variable "replicas" {
  description = "Nombre de replicas"
  type        = number
}

variable "host" {
  description = "Nom d'hote de l'Ingress"
  type        = string
}

variable "hpa_min" {
  description = "Plancher de l'autoscaler"
  type        = number
  default     = 3
}

variable "hpa_max" {
  description = "Plafond de l'autoscaler"
  type        = number
  default     = 8
}

variable "hpa_cpu_target" {
  description = "Cible d'utilisation CPU en pourcentage du requests"
  type        = number
  default     = 50
}

variable "kyverno_active" {
  description = "Cree la ClusterPolicy Kyverno. Necessite que Kyverno soit installe sur le cluster."
  type        = bool
  default     = true
}
