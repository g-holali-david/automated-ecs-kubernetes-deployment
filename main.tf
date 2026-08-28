# Une meme application, deux orchestrateurs, un seul etat Terraform.
# Le pipeline Jenkins applique les deux cibles en une passe.

module "ecs" {
  source = "./modules/ecs"

  projet        = var.projet
  image         = var.image
  lab_role_arn  = var.lab_role_arn
  desired_count = var.ecs_desired_count
}

module "k8s" {
  source = "./modules/k8s"

  projet         = var.projet
  image          = var.image
  replicas       = var.k8s_replicas
  host           = var.k8s_host
  kyverno_active = var.kyverno_active
}
