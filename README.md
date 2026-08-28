# Orchestration automatisée : ECS et Kubernetes

Déploiement de la même application sur deux orchestrateurs, Amazon ECS (Fargate) et
Kubernetes, avec une seule chaîne Terraform + Jenkins.

Projet IPSSI - Mastère Cybersécurité - Amazon AWS : ECS & EKS

Binôme : Holali David GAVI, Claire Danièle EBA

## Architecture

```
                      ┌──────────────┐
                      │     Git      │  code Terraform + Jenkinsfile
                      └──────┬───────┘
                             │ checkout
                      ┌──────▼───────┐
                      │   Jenkins    │  validate > plan > approbation > apply
                      └──────┬───────┘
                             │ pilote
                      ┌──────▼───────┐
                      │  Terraform   │  un seul état, deux providers
                      └───┬──────┬───┘
                provider  │      │  provider
                   aws    │      │  kubernetes
              ┌───────────▼┐    ┌▼─────────────┐
              │ Amazon ECS │    │  Kubernetes  │
              │  (Fargate) │    │  (Minikube)  │
              ├────────────┤    ├──────────────┤
              │ ECR        │    │ Namespace    │
              │ Cluster    │    │ ConfigMap    │
              │ TaskDef    │    │ Deployment   │
              │ Service    │    │ Service      │
              │ ALB + SG   │    │ Ingress      │
              │            │    │ HPA          │
              └────────────┘    └──────────────┘
```

Un `terraform apply` déploie les deux cibles. Le pipeline Jenkins l'exécute après
validation du plan.

## Structure du dépôt

```
.
├── Jenkinsfile                 pipeline pilotant les deux cibles
├── providers.tf                providers aws + kubernetes
├── backend.tf                  etat Terraform stocke sur S3
├── main.tf                     appelle les modules ecs et k8s
├── variables.tf                variables communes et par cible
├── outputs.tf                  URLs et état des deux déploiements
├── terraform.tfvars.example    modèle de configuration locale
├── modules/
│   ├── ecs/                    ECR, cluster Fargate, task definition, ALB, SG
│   └── k8s/                    Namespace, ConfigMap, Deployment, Service, Ingress, HPA
├── scripts/                    accès au cluster Minikube depuis Jenkins
└── docs/                       schéma d'architecture et rapport
```

## Prérequis

| Outil | Rôle |
|---|---|
| Terraform >= 1.5 | décrit et applique les deux cibles |
| AWS CLI v2 | identifiants AWS Academy (`us-east-1`) |
| kubectl + Minikube | cluster Kubernetes local |
| Jenkins | exécution du pipeline |
| Docker | construction et publication de l'image |

Démarrage du cluster :

```bash
minikube start -p projet-ipssi --driver=docker --cni=calico
minikube addons enable ingress -p projet-ipssi
minikube addons enable metrics-server -p projet-ipssi
```

`metrics-server` est nécessaire au HPA et `ingress` à l'exposition par nom d'hôte.
Calico est utile si on ajoute des NetworkPolicy : le CNI par défaut de Minikube les
accepte sans les appliquer.

L'image de l'application est chargée dans le cluster :

```bash
minikube image load web-ipssi:v7.0.0 -p projet-ipssi
```

## Configuration

Les identifiants AWS Academy expirent à chaque session et ne sont pas versionnés.
Ils sont fournis par l'environnement ou par `aws configure`.

```bash
cp terraform.tfvars.example terraform.tfvars
aws iam get-role --role-name LabRole --query Role.Arn --output text
```

L'ARN obtenu est à reporter dans `terraform.tfvars`.

L'état Terraform est stocké sur S3 (`backend.tf`), ce qui permet au poste de travail et
à Jenkins de travailler sur le même état. Le bucket est versionné et chiffré, et son
accès public est bloqué.

## Exécution manuelle

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

```bash
terraform output ecs_url    # http://<alb>.us-east-1.elb.amazonaws.com
terraform output k8s_url    # http://boutique.local
```

Destruction :

```bash
terraform destroy
```

## Exécution par le pipeline

Job Jenkins de type Pipeline, "Pipeline script from SCM", Git vers ce dépôt,
branche `*/main`, Script Path `Jenkinsfile`.

| Étape | Rôle |
|---|---|
| Checkout | récupère le code versionné |
| Init | `terraform init` |
| Validate | `terraform fmt -check -recursive` et `terraform validate` |
| Plan | un plan couvrant les deux cibles, archivé comme artefact |
| Approve | le pipeline attend une validation avant d'appliquer |
| Apply | applique le plan validé |
| Verify | interroge ECS et Kubernetes en parallèle |

Jenkins tournant dans WSL, il faut lui donner l'accès au cluster après chaque
démarrage de Minikube, car le port de l'API change :

```bash
sudo bash scripts/refresh-kubeconfig.sh projet-ipssi
sudo bash scripts/sync-aws-credentials.sh
```

Le second script recopie les identifiants AWS Academy vers le compte `jenkins`, à
relancer à chaque nouvelle session. L'ARN du LabRole est fourni à Jenkins par la
variable d'environnement globale `TF_VAR_lab_role_arn`, définie hors du dépôt.

## Sécurité

- Moindre privilège : `LabRole` comme execution role côté ECS, AWS Academy interdisant
  la création de rôles. Le Security Group des tâches n'accepte que le trafic venant de
  l'ALB, pas Internet.
- Pas de secret en dur : identifiants AWS hors dépôt, `terraform.tfvars` et
  `terraform.tfstate` ignorés par Git. Le mot de passe PostgreSQL est généré par
  Terraform et stocké dans un Secret Kubernetes.
- Images taguées : jamais `latest`. Le dépôt ECR est en mode `IMMUTABLE` avec scan de
  vulnérabilités au push, et une ClusterPolicy Kyverno refuse les pods sans tag explicite.

## Résilience

| | ECS | Kubernetes |
|---|---|---|
| Réplicas | `desired_count = 2` | `replicas = 3` |
| Auto-réparation | scheduler ECS | ReplicaSet |
| Sondes | health check ALB | readiness + liveness |
| Zéro coupure | `minimum_healthy_percent = 100` | `maxUnavailable: 0` et hook `preStop` |
| Rollback auto | deployment circuit breaker | `kubectl rollout undo` |
| Mise à l'échelle | `desired_count` | HPA sur le CPU (3 à 8) |

## Répartition du binôme

| Partie | Responsable |
|---|---|
| Cadrage et architecture | |
| Module ECS | |
| Module Kubernetes | |
| Pipeline Jenkins | |
| Rapport et démonstration | |
