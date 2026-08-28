# Captures a realiser sur la stack de Claire Daniele EBA

Meme liste que `docs/captures-stack-david`, prises sur son compte AWS Academy
et son cluster Minikube. Nommer les fichiers avec la meme numerotation pour que
le rapport puisse renvoyer aux deux series.

## Prealable : deployer la stack

L'etat Terraform et le depot ECR du binome sont sur le compte de David, qui n'est
pas accessible depuis un autre compte Academy. Il faut donc pointer sur les siens.

1. Creer le bucket d'etat :

```bash
aws s3api create-bucket --bucket tfstate-ipssi-<ID_DE_VOTRE_COMPTE> --region us-east-1
```

2. Initialiser Terraform sur ce bucket :

```bash
terraform init -reconfigure -backend-config="bucket=tfstate-ipssi-<ID_DE_VOTRE_COMPTE>"
```

3. Renseigner `terraform.tfvars` (copie de `terraform.tfvars.example`) avec son
   ARN de LabRole, son URL ECR et le nom de son contexte kubectl.

4. Construire et publier l'image, puis la charger dans son cluster :

```bash
docker build -t boutique:v8.1.0 . && docker tag boutique:v8.1.0 <SON_ECR>/boutique:v8.1.0 && docker push <SON_ECR>/boutique:v8.1.0
```

```bash
minikube image load web-ipssi:v8.1.0 -p <SON_PROFIL>
```

## Liste des captures

| # | Fichier | Contenu |
|---|---|---|
| 01 | `01-app-ecs-alb.png` | L'application servie par l'ALB |
| 02 | `02-console-aws-ecs-service.png` | Le service ECS, tasks running |
| 03 | `03-task-definition.png` | La task definition, execution role LabRole |
| 04 | `04-alb-target-group-healthy.png` | Les cibles du target group en healthy |
| 05 | `05-security-group-taches.png` | La regle entrante limitee au SG de l'ALB |
| 06 | `06-ecr-tag-immutable.png` | Le depot ECR en mode immutable |
| 07 | `07-ecr-images-versions.png` | Les images publiees et leurs tags |
| 08 | `08-cloudwatch-logs.png` | Le groupe de logs de l'application |
| 09 | `09-app-kubernetes-ingress.png` | L'application servie par l'Ingress |
| 10 | `10-k8s-deployments.png` | Les Deployments du namespace |
| 11 | `11-k8s-pods.png` | Les pods, leur noeud et leur image |
| 12 | `12-k8s-services.png` | Les Services |
| 13 | `13-k8s-ingress.png` | L'Ingress et son hote |
| 14 | `14-k8s-configmap.png` | La ConfigMap |
| 15 | `15-k8s-secret.png` | Le Secret de la base |
| 16 | `16-k8s-pvc.png` | La PVC liee a son volume |
| 17 | `17-k8s-node.png` | Le noeud du cluster |
| 18 | `18-k8s-hpa.png` | Le HPA et ses seuils |
| 19 | `19-k8s-kyverno-policy.png` | La ClusterPolicy Kyverno |
| 20 | `20-kyverno-refus.png` | Le refus d'un pod en `:latest` |
| 21 | `21-jenkins-pipeline.png` | Le pipeline Jenkins complet |

Pour la 20 :

```bash
kubectl run test-latest --image=nginx:latest -n boutique
```
