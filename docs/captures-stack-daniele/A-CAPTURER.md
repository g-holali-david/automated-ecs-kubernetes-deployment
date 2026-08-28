# Captures de la stack de Claire Daniele EBA

Captures prises sur son propre code, son compte AWS Academy et son cluster Minikube.
Les noms de ressources et de cluster lui sont propres : cette liste decrit ce que
chaque capture doit montrer, pas des noms imposes.

Garder la meme numerotation que `docs/captures-stack-david` pour que le rapport
puisse renvoyer aux deux series.

## Cible ECS

| # | Ce que la capture doit montrer |
|---|---|
| 01 | L'application repondant sur l'URL publique de l'ALB |
| 02 | Le service ECS : statut actif, nombre de taches en cours, dernier deploiement termine |
| 03 | La task definition : execution role, mode reseau, CPU et memoire |
| 04 | Le target group : cibles en `healthy` |
| 05 | Le security group des taches : la regle entrante n'autorise que le SG de l'ALB |
| 06 | Le depot ECR : immutabilite des tags et chiffrement |
| 07 | Les images publiees avec leurs tags explicites |
| 08 | Le groupe de logs CloudWatch et ses flux |

## Cible Kubernetes

| # | Ce que la capture doit montrer |
|---|---|
| 09 | L'application repondant via l'Ingress |
| 10 | Les Deployments et leurs images |
| 11 | Les pods : noeud, image, statut `Running` |
| 12 | Les Services et leurs IP de cluster |
| 13 | L'Ingress et son hote |
| 14 | La ConfigMap |
| 15 | Le Secret de la base (valeur masquee) |
| 16 | La PVC liee a son volume |
| 17 | Le noeud du cluster, avec un nom identifiable |
| 18 | Le HPA : seuil CPU, min et max de replicas |
| 19 | La ClusterPolicy Kyverno |
| 20 | Le refus d'un pod en `:latest` par Kyverno |

## Chaine d'automatisation

| # | Ce que la capture doit montrer |
|---|---|
| 21 | Le pipeline Jenkins, etapes et resultat |

## Remarques

Le nom du cluster Minikube doit etre parlant, pour que le correcteur distingue
les deux stacks sur les captures.

La ClusterPolicy Kyverno est une ressource personnalisee et non namespacee :
dans Freelens elle se trouve sous **Custom Resources > kyverno.io > ClusterPolicy**,
et le filtre de namespace doit etre sur tous les namespaces.

Pour la capture 20 :

```bash
kubectl run test-latest --image=nginx:latest -n <SON_NAMESPACE>
```
