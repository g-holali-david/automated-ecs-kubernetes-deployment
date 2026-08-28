# Garde-fou de securite : interdit le tag :latest dans le namespace applicatif.
#
# Une image en :latest n'est pas une version mais un pointeur mouvant : deux
# deploiements du meme manifeste peuvent lancer des images differentes, et le
# rollback devient impossible a garantir.
#
# Prerequis : Kyverno doit etre installe sur le cluster (ses CRD doivent exister
# au moment du plan, sinon kubernetes_manifest echoue) :
#   helm install kyverno kyverno/kyverno -n kyverno --create-namespace --wait

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
            # Enforce : la creation est refusee, pas seulement signalee
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
