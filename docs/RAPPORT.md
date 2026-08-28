# Orchestration automatisée : ECS et Kubernetes

**Projet IPSSI - Mastère Cybersécurité - Amazon AWS : ECS & EKS**

**Binôme :** Holali David GAVI, Claire Danièle EBA

**Dépôt :** https://github.com/g-holali-david/automated-ecs-kubernetes-deployment

---

## 1. Cadrage et architecture

### 1.1 Besoin

L'entreprise exploite la même application conteneurisée sur deux plateformes : ECS pour la
production cloud, Kubernetes pour la portabilité hors AWS. Il ne s'agit pas de choisir entre les
deux mais d'industrialiser les deux déploiements avec une seule chaîne d'automatisation.

| Exigence | Traduction technique |
|---|---|
| Charge | 2 tâches sur ECS, 3 réplicas sur Kubernetes, montée automatique jusqu'à 8 |
| Disponibilité | Aucune coupure en mise à jour, redémarrage automatique d'une instance en échec |
| Sécurité | Moindre privilège réseau, aucun secret dans le dépôt, images à tag figé |
| Coût | Fargate en 0,25 vCPU et 512 Mio, rétention des logs à 7 jours |

### 1.2 Application et contraintes

Nous réutilisons l'application des TP précédents, une application Node.js avec Express. Elle
affiche son contexte d'exécution, ce qui permet de prouver visuellement sur quelle cible on se
trouve. Elle intègre une base PostgreSQL, non demandée par le sujet, que nous avons ajoutée pour
aller plus loin. Elle démarre sans base, en mode dégradé, ce qui est expliqué en 2.3.

AWS Academy impose `us-east-1`, interdit la création de rôles IAM et fournit des identifiants
temporaires. Le rôle `LabRole` sert donc d'execution role. EKS étant indisponible pour la même
raison, la cible Kubernetes est un cluster Minikube nommé `projet-ipssi`, identifiable sur les
captures. Les ressources restent transposables vers EKS.

### 1.3 Architecture cible

```
        ┌──────────┐   checkout   ┌───────────┐   pilote   ┌────────────┐
        │   Git    │─────────────►│  Jenkins  │───────────►│ Terraform  │
        └──────────┘              └───────────┘            └─────┬──────┘
                        validate > plan > approbation      aws │ │ kubernetes
                                  > apply > verify             │ │
                        ┌──────────────────────────────────────┘ └───────┐
                        ▼                                                ▼
              ┌──────────────────┐                          ┌──────────────────┐
              │   Amazon ECS     │                          │    Kubernetes    │
              │    (Fargate)     │                          │    (Minikube)    │
              ├──────────────────┤                          ├──────────────────┤
              │ ECR, Cluster     │                          │ Namespace        │
              │ TaskDef, Service │                          │ ConfigMap,Secret │
              │ ALB + 2 SG       │                          │ Deployment, Svc  │
              │ CloudWatch Logs  │                          │ Ingress, HPA     │
              └──────────────────┘                          │ PVC, Kyverno     │
                                                            └──────────────────┘
                                   État Terraform partagé sur S3 (versionné, chiffré)
```

Le point clé est qu'il n'y a **qu'un seul état Terraform** pour les deux cibles. Un
`terraform apply` unique les réconcilie. Le code est organisé en deux modules, `modules/ecs` et
`modules/k8s`, appelés depuis un `main.tf` racine, soit 26 ressources.

---

## 2. Déploiement sur ECS

### 2.1 Ressources et exposition

Le module `ecs` crée le dépôt ECR, le cluster Fargate, la task definition, le service, un ALB avec
son target group et son listener, deux Security Groups et un groupe de logs CloudWatch. Le VPC et
les sous-réseaux par défaut sont récupérés par des data sources, AWS Academy interdisant la
création d'un réseau complet.

Le target group est en mode `ip`, seule valeur possible avec le mode réseau `awsvpc` de Fargate.

![Capture 02](captures-stack-david/02-console-aws-ecs-service.png)

*Capture 02 : le service `boutique-svc`, 2 tâches sur 2 actives, déploiement terminé.*

![Capture 03](captures-stack-david/03-task-definition-boutique-4.png)

*Capture 03 : la task definition. L'execution role est `LabRole` et le mode réseau `awsvpc`.*

![Capture 01](captures-stack-david/01-app-ecs-alb.png)

*Capture 01 : l'application répond sur l'URL publique de l'ALB.*

### 2.2 Mise à l'échelle et auto-réparation

Le nombre de tâches est piloté par `ecs_desired_count`, fixée à 2. Le scheduler ECS relance
automatiquement toute tâche arrêtée pour revenir au compte souhaité.

![Capture 04](captures-stack-david/04-alb-target-group-healthy.png)

*Capture 04 : les 2 cibles enregistrées sont en `healthy` sur le port 8080.*

Une correction a été nécessaire : le target group porte un nom généré par `name_prefix` avec
`create_before_destroy`. Sans cela, un changement de port force son remplacement, et AWS refuse de
supprimer l'ancien tant que le listener le référence.

### 2.3 Pas de base de données sur cette cible

Le sujet ne demande pas de base de données. Nous en avons déployé une uniquement sur Kubernetes.
Sur ECS, RDS aurait dépassé le périmètre, et un conteneur PostgreSQL dans la même tâche aurait
perdu ses données à chaque redémarrage.

C'est **le même artefact** sur les deux cibles : même image, même tag, même empreinte. Seule la
configuration d'exécution diffère, ce qui est le rôle de la ConfigMap d'un côté et des variables
de la task definition de l'autre.

Sans base joignable, l'application démarre en mode dégradé : les pages restent servies et la
création de compte est désactivée. Les sondes sont séparées en conséquence. La liveness interroge
`/health`, qui répond toujours 200 tant que le processus tourne. La readiness interroge `/ready`,
qui répond 503 sans base. Si la liveness avait dépendu de la base, une base absente aurait fait
redémarrer l'application en boucle alors qu'elle servait encore des pages.

---

## 3. Déploiement sur Kubernetes

### 3.1 Ressources

Le module `k8s` crée le namespace, une ConfigMap, un Secret, le Deployment de l'application, son
Service en `ClusterIP`, l'Ingress, le HorizontalPodAutoscaler, la ClusterPolicy Kyverno, ainsi que
le Deployment, le Service et la PersistentVolumeClaim de PostgreSQL. Aucun Service n'est exposé
directement : l'entrée se fait uniquement par l'Ingress.

![Capture 11](captures-stack-david/11-k8s-pods.png)

*Capture 11 : les quatre pods en `Running` sur le nœud `projet-ipssi`, avec leur consommation
relevée par metrics-server.*

![Capture 13](captures-stack-david/13-k8s-ingress.png)

*Capture 13 : l'Ingress `boutique-ingress` sur l'hôte `boutique.local`.*

![Capture 09](captures-stack-david/09-app-kubernetes-ingress.png)

*Capture 09 : l'application servie par l'Ingress. Le namespace, le pod et le nœud sont renseignés,
contrairement à la capture 01 sur ECS.*

### 3.2 Configuration, secrets et persistance

La configuration non sensible passe par une ConfigMap. Le mot de passe PostgreSQL est généré par
Terraform avec `random_password` et stocké dans un Secret. Le pod reçoit aussi son nom, son
namespace et son nœud par l'API Downward.

![Capture 15](captures-stack-david/15-k8s-secret.png)

*Capture 15 : le Secret de la base. Le mot de passe n'apparaît ni dans la ConfigMap ni dans le
dépôt.*

PostgreSQL monte une PersistentVolumeClaim de 1 Gio en `ReadWriteOnce`, provisionnée dynamiquement
par Minikube. Sa stratégie de déploiement est en `Recreate` et non `RollingUpdate` : un volume
`ReadWriteOnce` n'est montable que par un pod à la fois. Les données sont écrites dans un
sous-répertoire du point de montage, celui-ci contenant un dossier `lost+found` que
l'initialisation de PostgreSQL refuse.

### 3.3 Mise à l'échelle

Le HorizontalPodAutoscaler ajuste le nombre de réplicas entre 3 et 8 selon la consommation CPU,
avec une cible de 50 %.

![Capture 18](captures-stack-david/18-k8s-hpa.png)

*Capture 18 : le HPA, ses seuils et ses conditions. `AbleToScale` confirme qu'il reçoit les
métriques.*

Le calcul se fait sur les `requests` déclarées dans le Deployment, ici 50 millicores. Sans
`requests`, le HPA n'a pas de base de calcul. Nous avons aussi réduit la fenêtre de stabilisation
de descente de 300 à 30 secondes pour rendre la redescente observable en démonstration.

### 3.4 Garde-fou de sécurité

Une ClusterPolicy Kyverno, décrite en Terraform, interdit en mode `Enforce` tout pod dont l'image
porte le tag `latest`. Nous l'avons vérifiée :

```bash
kubectl run test-latest --image=nginx:latest -n boutique
```

![Capture 20](captures-stack-david/20-kyverno-refus.png)

*Capture 20 : le webhook d'admission refuse la création. Le message affiché est celui écrit dans
notre règle, ce qui prouve que c'est bien notre politique qui agit. Le pod n'est pas créé.*

---

## 4. Automatisation avec Jenkins

Un `Jenkinsfile` unique, versionné, pilote les deux cibles. Le job est de type Pipeline from SCM :
il lit le Jenkinsfile depuis Git, donc le pipeline évolue avec le code.

| Étape | Rôle |
|---|---|
| Checkout | récupère le code versionné |
| Init | `terraform init`, connexion au backend S3 |
| Validate | `terraform fmt -check -recursive` puis `terraform validate` |
| Plan | un plan couvrant les deux cibles, archivé comme artefact |
| Approve | le pipeline s'arrête et attend une validation humaine |
| Apply | applique le plan validé |
| Verify | interroge ECS et Kubernetes en parallèle |

![Capture 21](captures-stack-david/21-jenkins-pipeline.png)

*Capture 21 : le pipeline complet.*

**Idempotence.** Sur une infrastructure déjà conforme, le plan annonce `No changes` et l'apply se
termine par `0 added, 0 changed, 0 destroyed`. C'est le backend S3 qui le permet : Jenkins
travaille dans un espace vierge à chaque exécution et, avec un état local, aurait tenté de recréer
les 26 ressources existantes. Le bucket est versionné, chiffré en AES-256, accès public bloqué.

**Gouvernance.** L'étape `Approve` arrête le pipeline et affiche le plan avant qu'il soit appliqué.
Aucune modification ne part sans relecture humaine.

---

## 5. Sécurité

**Moindre privilège réseau.** Le Security Group de l'ALB accepte le HTTP depuis Internet. Celui des
tâches n'accepte que le port 8080, et uniquement depuis le Security Group de l'ALB. Une tâche n'est
joignable qu'à travers le répartiteur de charge.

![Capture 05](captures-stack-david/05-security-group-taches.png)

*Capture 05 : une seule règle entrante, dont la source est le Security Group de l'ALB.*

**Moindre privilège IAM.** L'execution role est `LabRole`. Aucun rôle n'est créé par le projet.

**Aucun secret en dur.** Les identifiants AWS sont temporaires et jamais versionnés.
`terraform.tfvars` et l'état Terraform sont exclus par `.gitignore`, l'état contenant en clair les
valeurs des ressources. Le mot de passe PostgreSQL est généré par Terraform et vit dans un Secret.
Côté Jenkins, l'ARN du LabRole vient d'une variable d'environnement définie hors du dépôt.

**Images taguées.** Le tag `latest` n'est utilisé nulle part. Le dépôt ECR est en mode `IMMUTABLE`,
donc un tag publié ne peut plus être écrasé, avec analyse de vulnérabilités à chaque push. Les
versions successives y coexistent avec des empreintes distinctes, aucune image n'ayant été écrasée
d'un déploiement à l'autre. Côté Kubernetes, Kyverno refuse tout pod sans tag explicite.

![Capture 06](captures-stack-david/06-ecr-tag-immutable.png)

*Capture 06 : le dépôt ECR en mode immuable, chiffré en AES-256.*

---

## 6. Résilience

| | ECS | Kubernetes |
|---|---|---|
| Instances | 2 tâches | 3 réplicas |
| Auto-réparation | scheduler ECS | ReplicaSet |
| Sondes | health check de l'ALB | readiness et liveness |
| Zéro coupure | `minimum_healthy_percent = 100` | `maxUnavailable: 0` et hook `preStop` |
| Retour arrière | deployment circuit breaker | `kubectl rollout undo` |
| Mise à l'échelle | `desired_count` | HPA sur le CPU, de 3 à 8 |

Sur ECS, le circuit breaker annule et restaure automatiquement un déploiement qui échoue. Avec
`minimum_healthy_percent` à 100, une nouvelle tâche est démarrée et déclarée saine avant qu'une
ancienne soit retirée. Nous l'avons observé lors d'un changement de version : deux tâches sont
restées en service pendant toute la bascule et l'ALB a répondu 200 sans interruption.

Sur Kubernetes, le même principe s'applique avec `maxUnavailable: 0` et `maxSurge: 1`. Un hook
`preStop` fait patienter le conteneur cinq secondes, le temps que le Service retire le pod de ses
endpoints, ce qui évite de perdre les requêtes en cours.

---

## 7. Reproductibilité et traçabilité

Les deux déploiements se recréent intégralement depuis le dépôt : dépôt ECR, cluster, service, ALB,
Security Groups, namespace, base et politique de gouvernance sont tous décrits en Terraform.

Trois éléments dépendent du poste et sont documentés dans le README : les identifiants AWS de la
session Academy, le nom du bucket d'état, et le chargement de l'image dans Minikube. Ce dernier
point vient d'une limite d'Academy : Minikube ne peut pas s'authentifier auprès d'ECR sans
imagePullSecret. Le projet se redéploie sur un autre compte Academy sans modifier une ligne de
code :

```bash
terraform init -reconfigure -backend-config="bucket=tfstate-ipssi-<ID_DU_COMPTE>"
```

Côté traçabilité, l'historique Git compte des commits atomiques aux messages explicites. Les
journaux applicatifs d'ECS sont centralisés dans CloudWatch avec une rétention de sept jours.
L'état sur S3 est versionné, ce qui permet de savoir quand une ressource a changé et de revenir en
arrière. Le plan de chaque exécution Jenkins est archivé comme artefact du build, laissant une
trace de ce qui a été soumis à approbation.

---

## 8. Difficultés rencontrées

| Problème | Cause | Solution |
|---|---|---|
| Suppression du target group refusée | le listener le référence encore | `name_prefix` et `create_before_destroy` |
| `CrashLoopBackOff` au premier déploiement | port 80 déclaré au lieu de 8080 | correction dans les deux modules |
| PostgreSQL refuse de s'initialiser | `lost+found` dans le point de montage | données dans un sous-répertoire |
| HPA sans effet | fenêtre de stabilisation trop longue | `select_policy` et fenêtre à 30 s |
| Jenkins voulait recréer les 26 ressources | espace de travail vierge, état local | backend S3 partagé |
| Vérification ECS en échec dans Jenkins | l'AWS CLI reprenait la région du poste | `AWS_DEFAULT_REGION` figée dans le Jenkinsfile |

La dernière est instructive. L'erreur mentionnait une ressource en `eu-west-3` alors que le projet
est en `us-east-1` : le fichier de configuration de l'AWS CLI du poste portait encore cette région.
Terraform n'était pas affecté, son provider fixant la région explicitement, mais l'AWS CLI appelée
dans l'étape de vérification, si. Figer la région dans le Jenkinsfile rend le pipeline indépendant
de la configuration de la machine.

---

## 9. Limites

La cible Kubernetes est un Minikube local. Vers EKS, l'Ingress devrait être remplacé par un
contrôleur adossé à un load balancer AWS et le stockage par une StorageClass EBS.

Le pipeline s'arrête au déploiement de l'infrastructure : la construction et la publication de
l'image restent manuelles. Une étape supplémentaire pourrait les intégrer avec un tag dérivé du
commit Git.

Enfin, les identifiants AWS sont recopiés vers le compte de service Jenkins par un script. En
production, on utiliserait le gestionnaire d'identifiants de Jenkins ou un rôle IAM porté par
l'agent.

---

## 10. Répartition du binôme

Chacun a écrit sa part du code, puis déployé et exploité sa propre stack, sur son compte AWS
Academy et son cluster Minikube. Les deux membres savent expliquer l'ensemble de la chaîne.

| Tâche | Holali David GAVI | Claire Danièle EBA |
|---|---|---|
| Cadrage du besoin | Rédaction | Relecture |
| Schéma d'architecture | Relecture | Rédaction |
| Module Terraform `ecs` | Relecture | Rédaction |
| Module Terraform `k8s` | Rédaction | Relecture |
| Scripts d'exploitation AWS | | Rédaction |
| Scripts d'exploitation Kubernetes | Rédaction | |
| Pipeline Jenkins | Version écrite puis comparée | Version écrite puis comparée |
| Rapport écrit | Rédaction | Relecture |
| Déploiement, captures, démonstration | Sa propre stack | Sa propre stack |

Chacun a écrit son propre `Jenkinsfile`. Nous les avons comparés puis retenu une seule version pour
le dépôt commun. Les captures de chaque stack sont dans le dépôt, sous `docs/captures-stack-david`
et `docs/captures-stack-daniele`.

---

## 11. Bilan

Les quatre briques sont en place. La même application tourne sur ECS Fargate et sur Kubernetes, les
deux déploiements sont décrits par un seul code Terraform en deux modules, et un pipeline Jenkins
gouverné les applique après approbation.

Ce que le projet nous a le plus appris n'est pas la syntaxe de Terraform mais la gestion de l'état.
Tant qu'il restait local, l'automatisation n'était qu'une apparence : le pipeline aurait détruit et
recréé une infrastructure existante. Le déplacer sur S3 a rendu la chaîne réellement idempotente,
condition pour qu'elle soit utilisable plus d'une fois.
