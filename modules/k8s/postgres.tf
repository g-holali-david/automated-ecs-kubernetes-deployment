# Base de donnees de la cible Kubernetes.
#
# L'application demarre sans base (mode degrade), mais la cible Kubernetes
# fournit PostgreSQL pour la faire tourner en mode complet : comptes,
# sessions partagees entre replicas et gestionnaire de taches.

resource "random_password" "db" {
  length  = 24
  special = false
}

# Le mot de passe est genere puis stocke dans un Secret : il n'apparait
# jamais dans le code versionne.
resource "kubernetes_secret_v1" "db" {
  metadata {
    name      = "${var.projet}-db"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }

  data = {
    POSTGRES_PASSWORD = random_password.db.result
    PGPASSWORD        = random_password.db.result
  }

  type = "Opaque"
}

resource "kubernetes_persistent_volume_claim_v1" "db" {
  metadata {
    name      = "${var.projet}-db"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }

  # Le PVC reste Pending tant qu'aucun pod ne le monte : on n'attend pas la liaison.
  wait_until_bound = false
}

resource "kubernetes_deployment_v1" "db" {
  metadata {
    name      = "${var.projet}-db"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "${var.projet}-db" }
    }

    # Un seul pod peut monter le volume ReadWriteOnce : on arrete l'ancien
    # avant de demarrer le nouveau.
    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = { app = "${var.projet}-db" }
      }

      spec {
        security_context {
          fs_group = 999
        }

        container {
          name  = "postgres"
          image = var.image_db

          security_context {
            run_as_non_root            = true
            run_as_user                = 999
            allow_privilege_escalation = false
          }

          port {
            container_port = 5432
          }

          env {
            name  = "POSTGRES_DB"
            value = var.db_name
          }

          env {
            name  = "POSTGRES_USER"
            value = var.db_user
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.db.metadata[0].name
                key  = "POSTGRES_PASSWORD"
              }
            }
          }

          # Sous-repertoire impose : le point de montage contient lost+found,
          # ce que l'initialisation de PostgreSQL refuse.
          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }

          volume_mount {
            name       = "donnees"
            mount_path = "/var/lib/postgresql/data"
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", var.db_user]
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }

          liveness_probe {
            exec {
              command = ["pg_isready", "-U", var.db_user]
            }
            initial_delay_seconds = 20
            period_seconds        = 10
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }

        volume {
          name = "donnees"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.db.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "db" {
  metadata {
    name      = "${var.projet}-db"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }

  spec {
    selector = { app = "${var.projet}-db" }
    type     = "ClusterIP"

    port {
      port        = 5432
      target_port = 5432
    }
  }
}
