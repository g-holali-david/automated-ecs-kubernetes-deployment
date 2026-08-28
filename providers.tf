terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# Cible 1 : Amazon ECS (AWS Academy, region imposee us-east-1)
provider "aws" {
  region = var.aws_region
}

# Cible 2 : Kubernetes (Minikube en local)
provider "kubernetes" {
  config_path    = var.kube_config_path
  config_context = var.kube_context
}
