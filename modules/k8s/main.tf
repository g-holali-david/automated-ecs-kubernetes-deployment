locals {
  labels = {
    app      = var.projet
    gere_par = "terraform"
  }
}

resource "kubernetes_namespace_v1" "app" {
  metadata {
    name   = var.projet
    labels = local.labels
  }
}

# Configuration non sensible, injectee en variables d'environnement
resource "kubernetes_config_map_v1" "app" {
  metadata {
    name      = "${var.projet}-config"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }

  data = {
    APP_ENV   = "production"
    APP_NOM   = "Boutique IPSSI"
    APP_CIBLE = "kubernetes"
  }
}

resource "kubernetes_deployment_v1" "app" {
  metadata {
    name      = var.projet
    namespace = kubernetes_namespace_v1.app.metadata[0].name
    labels    = local.labels
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = { app = var.projet }
    }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        # Aucune capacite perdue pendant une mise a jour
        max_unavailable = 0
        max_surge       = 1
      }
    }

    template {
      metadata {
        labels = local.labels
      }

      spec {
        container {
          name  = "web"
          image = var.image

          port {
            container_port = 80
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map_v1.app.metadata[0].name
            }
          }

          # Laisse le temps au Service de retirer le pod avant l'arret
          lifecycle {
            pre_stop {
              exec {
                command = ["/bin/sh", "-c", "sleep 5"]
              }
            }
          }

          # Retire le pod du Service tant qu'il n'est pas pret
          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 3
            period_seconds        = 5
          }

          # Redemarre le conteneur s'il ne repond plus
          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          # requests = base de calcul du HPA, limits = plafond
          resources {
            requests = {
              cpu    = "50m"
              memory = "32Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "app" {
  metadata {
    name      = "${var.projet}-svc"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }

  spec {
    selector = { app = var.projet }
    type     = "ClusterIP"

    port {
      port        = 80
      target_port = 80
    }
  }
}

resource "kubernetes_ingress_v1" "app" {
  metadata {
    name      = "${var.projet}-ingress"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = var.host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.app.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "app" {
  metadata {
    name      = "${var.projet}-hpa"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.app.metadata[0].name
    }

    min_replicas = var.hpa_min
    max_replicas = var.hpa_max

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = var.hpa_cpu_target
        }
      }
    }

    behavior {
      scale_down {
        # Reduit de 300s a 30s pour rendre la descente observable en demonstration
        stabilization_window_seconds = 30
        # Obligatoire des qu'une policy est declaree
        select_policy = "Max"
        policy {
          type           = "Percent"
          value          = 100
          period_seconds = 15
        }
      }
    }
  }
}
