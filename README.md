# Orchestration automatisée : ECS et Kubernetes

Déploiement d'une **même application** sur **deux orchestrateurs** — Amazon ECS (Fargate) et
Kubernetes — pilotés par une **chaîne unique** Terraform + Jenkins.

Projet IPSSI — Mastère Cybersécurité — Amazon AWS : ECS & EKS

**Binôme :** Holali David GAVI · Claire Danièle EBA

---

## Architecture

```
                      ┌──────────────┐
                      │     Git      │  code Terraform + Jenkinsfile
                      └──────┬───────┘
                             │ checkout
                      ┌──────▼───────┐
                      │   Jenkins    │  validate → plan → APPROBATION → apply
                      └──────┬───────┘
                             │ pilote
                      ┌──────▼───────┐
                      │  Terraform   │  un seul état, deux providers
                      └───┬──────┬───┘
                provider  │      │  provider
                   aws    │      │  kubernetes
              ┌───────────▼┐    ┌▼─────────────┐
              │  Amazon ECS │    │  Kubernetes  │
              │  (Fargate)  │    │  (Minikube)  │
              ├─────────────┤    ├──────────────┤
              │ ECR         │    │ Namespace    │
              │ Cluster     │    │ ConfigMap    │
              │ TaskDef     │    │ Deployment   │
              │ Service     │    │ Service      │
              │ ALB + SG    │    │ Ingress      │
              │             │    │ HPA          │
              └─────────────┘    └──────────────┘
```

Une seule commande `terraform apply` déploie les deux cibles ; le pipeline Jenkins
l'exécute après validation humaine du plan.

---

## Structure du dépôt

```
.
├── Jenkinsfile                 pipeline unique pilotant les deux cibles
├── providers.tf                providers aws + kubernetes
├── main.tf                     appelle les modules ecs et k8s
├── variables.tf                variables communes et par cible
├── outputs.tf                  URLs et état des deux déploiements
├── terraform.tfvars.example    modèle de configuration locale
├── modules/
│   ├── ecs/                    ECR, cluster Fargate, task definition, ALB, SG
│   └── k8s/                    Namespace, ConfigMap, Deployment, Service, Ingress, HPA
└── docs/                       schéma d'architecture et rapport
```

---

## Prérequis

| Outil | Rôle |
|---|---|
| Terraform ≥ 1.5 | décrit et applique les deux cibles |
| AWS CLI v2 | identifiants AWS Academy (`us-east-1`) |
| kubectl + Minikube | cluster Kubernetes local |
| Jenkins | orchestration du pipeline |
| Docker | construction et publication de l'image |

Le cluster Minikube doit tourner avec les addons requis :

```bash
minikube start -p eval --driver=docker --cni=calico
minikube addons enable ingress -p eval
minikube addons enable metrics-server -p eval
```

> `metrics-server` est indispensable au HPA, `ingress` à l'exposition par nom d'hôte.
> Calico est nécessaire si des NetworkPolicy sont ajoutées : le CNI par défaut de
> Minikube les accepte sans les appliquer.

---

## Configuration

Les identifiants AWS Academy expirent à chaque session : ils ne sont **jamais** versionnés.
Les renseigner via l'environnement ou `aws configure`.

```bash
cp terraform.tfvars.example terraform.tfvars
```

Puis renseigner l'ARN du LabRole de votre compte :

```bash
aws iam get-role --role-name LabRole --query Role.Arn --output text
```

---

## Exécution manuelle

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Résultat :

```bash
terraform output ecs_url    # http://<alb>.us-east-1.elb.amazonaws.com
terraform output k8s_url    # http://boutique.local
```

Destruction :

```bash
terraform destroy
```

---

## Exécution par le pipeline

Job Jenkins de type **Pipeline** → *Pipeline script from SCM* → Git → ce dépôt →
branche `*/main` → Script Path `Jenkinsfile`.

| Étape | Rôle |
|---|---|
| Checkout | récupère le code versionné |
| Init | `terraform init` |
| Validate | `terraform fmt -check -recursive` + `terraform validate` |
| Plan | un plan couvrant **les deux** cibles, archivé comme artefact |
| **Approve** | **le pipeline s'arrête** — aucun apply sans relecture humaine |
| Apply | applique le plan validé |
| Verify | interroge ECS et Kubernetes en parallèle |

---

## Sécurité

- **Moindre privilège** : `LabRole` en execution role côté ECS (AWS Academy interdit la
  création de rôles) ; le Security Group des tâches n'accepte **que** le trafic de l'ALB,
  jamais Internet directement.
- **Aucun secret en dur** : identifiants AWS hors dépôt, `terraform.tfvars` ignoré par Git,
  `terraform.tfstate` exclu (il contient en clair les valeurs des ressources).
- **Images taguées** : jamais `latest`. Le dépôt ECR est en `IMMUTABLE` — un tag publié ne
  peut plus être écrasé — avec scan de vulnérabilités à chaque push.

## Résilience

| | ECS | Kubernetes |
|---|---|---|
| Réplicas | `desired_count = 2` | `replicas = 3` |
| Auto-réparation | scheduler ECS | ReplicaSet |
| Sondes | health check ALB | readiness + liveness |
| Zéro coupure | `minimum_healthy_percent = 100` | `maxUnavailable: 0` + hook `preStop` |
| Rollback auto | deployment circuit breaker | `kubectl rollout undo` |
| Mise à l'échelle | `desired_count` | HPA sur le CPU (3 → 8) |

---

## Répartition du binôme

À compléter avant le rendu — chacun doit savoir expliquer l'ensemble.

| Partie | Responsable |
|---|---|
| Cadrage & architecture | |
| Module ECS | |
| Module Kubernetes | |
| Pipeline Jenkins | |
| Rapport & démonstration | |
