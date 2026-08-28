# Les deux cibles sont declarees dans le meme etat Terraform.

module "ecs" {
  source = "./modules/ecs"

  projet        = var.projet
  auteurs       = var.auteurs
  image         = var.image_ecs
  lab_role_arn  = var.lab_role_arn
  desired_count = var.ecs_desired_count
}

module "k8s" {
  source = "./modules/k8s"

  projet         = var.projet
  auteurs        = var.auteurs
  image          = var.image_k8s
  replicas       = var.k8s_replicas
  host           = var.k8s_host
  kyverno_active = var.kyverno_active
}
