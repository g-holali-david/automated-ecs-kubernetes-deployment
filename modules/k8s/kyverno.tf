# Interdit le tag latest dans le namespace. Necessite Kyverno installe sur le cluster.
resource "kubernetes_manifest" "interdire_tag_latest" {
  count = var.kyverno_active ? 1 : 0

  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"

    metadata = {
      name = "${var.projet}-interdire-latest"
    }

    spec = {
      rules = [
        {
          name = "verifier-tag-image"

          match = {
            any = [
              {
                resources = {
                  kinds      = ["Pod"]
                  namespaces = [var.projet]
                }
              }
            ]
          }

          validate = {
            failureAction = "Enforce"
            message       = "Un tag d'image explicite est requis (le tag latest est interdit)."

            pattern = {
              spec = {
                containers = [
                  {
                    image = "!*:latest"
                  }
                ]
              }
            }
          }
        }
      ]
    }
  }

  depends_on = [kubernetes_namespace_v1.app]
}
