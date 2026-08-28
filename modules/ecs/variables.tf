variable "projet" {
  description = "Prefixe des ressources"
  type        = string
}

variable "image" {
  description = "Image applicative taguee (jamais latest)"
  type        = string
}

variable "lab_role_arn" {
  description = "Execution role des taches. AWS Academy interdit la creation de roles : on reutilise LabRole."
  type        = string
}

variable "desired_count" {
  description = "Nombre de taches Fargate souhaitees"
  type        = number
  default     = 2
}

variable "container_port" {
  description = "Port ecoute par le conteneur"
  type        = number
  default     = 80
}

variable "cpu" {
  description = "CPU de la tache (unites Fargate)"
  type        = string
  default     = "256"
}

variable "memory" {
  description = "Memoire de la tache en Mio"
  type        = string
  default     = "512"
}
