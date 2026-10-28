# LIVRABLE 3 : RAPPORT D'INFRASTRUCTURE, AUTOMATISATION & GUIDE DE DÉMONSTRATION
**Projet et Déploiement d'Infrastructure Cloud AWS (3-Tiers)**
*Établissement : TEK-UP — Promotion ING-4 (Module ING-4-CIM)*  
*Enseignant responsable : Hamdi Chebbi*

---

## 1. Description Détaillée de l'Infrastructure Déployée par IaC

L'intégralité de l'infrastructure est codée en **Terraform modulaire** (`infra/modules/`) orchestrée par l'environnement de développement (`infra/environments/dev/main.tf`). Aucune ressource n'est créée manuellement via la console AWS.

```
infra/
├── environments/dev/
│   ├── main.tf              # Assemblage des 6 modules avec passages de variables
│   ├── variables.tf         # Paramètres par défaut (région us-east-1, préfixe cinetrekker-dev)
│   └── outputs.tf           # Sorties (URL ALB, /health, bucket S3, dashboard CloudWatch)
└── modules/
    ├── reseau/              # VPC, 6 sous-réseaux, tables de routage, NAT, S3 Endpoint
    ├── securite/            # 4 Security Groups chaînés par référence
    ├── stockage/            # Bucket S3, règles de chiffrement, archive et secret DB
    ├── base-de-donnees/     # RDS PostgreSQL 15, DB subnet group, sauvegardes
    ├── calcul/              # ALB, Target Group /health, Launch Template, ASG
    └── supervision/         # CloudWatch Log Group (1j), Dashboard, 2 Alarmes métriques
```

### 1.1 Réseau et Segmentation Multi-AZ (`modules/reseau`)
* **VPC Dédié** : Bloc d'adresses `10.0.0.0/16` avec résolution et noms d'hôtes DNS activés (`enable_dns_hostnames = true`).
* **Découpage en 6 Sous-réseaux (3 Tiers $\times$ 2 Zones de Disponibilité)** :
  1. `cinetrekker-dev-public-subnet-1a` (`10.0.1.0/24`, `us-east-1a`) : Nœud ALB 1 et Instance NAT.
  2. `cinetrekker-dev-public-subnet-1b` (`10.0.2.0/24`, `us-east-1b`) : Nœud ALB 2.
  3. `cinetrekker-dev-private-app-subnet-1a` (`10.0.11.0/24`, `us-east-1a`) : Instances EC2 applicatives ASG.
  4. `cinetrekker-dev-private-app-subnet-1b` (`10.0.12.0/24`, `us-east-1b`) : Instances EC2 applicatives ASG.
  5. `cinetrekker-dev-private-db-subnet-1a` (`10.0.21.0/24`, `us-east-1a`) : Base de données RDS PostgreSQL.
  6. `cinetrekker-dev-private-db-subnet-1b` (`10.0.22.0/24`, `us-east-1b`) : Plage de secours DB Subnet Group.
* **Tables de Routage Explicites** :
  * **Table Publique** : Route `0.0.0.0/0` vers l'Internet Gateway (`cinetrekker-dev-igw`).
  * **Table Privée Applicative** : Route `0.0.0.0/0` vers l'interface réseau primaire (ENI) de l'instance NAT + Route préfixée locale vers le point de terminaison S3.
  * **Table Base de Données** : Aucune passerelle Internet associée (isolation complète).
* **Point de Terminaison S3 Gateway Endpoint** : Relié directement aux tables publique et privée pour router le trafic vers Amazon S3 sans consommer de bande passante Internet.

### 1.2 Sécurité et Périmètre Réseau (`modules/securite`)
* **Principe du Moindre Privilège** : Aucun Security Group interne n'autorise d'adresses IP directes. Tout flux interne est sécurisé par **chaînage d'identifiants de groupes** (`Security Group Chaining`).
* **Flux Autorisés** :
  * `cinetrekker-dev-alb-sg` : Entrée HTTP port 80 depuis `0.0.0.0/0` $\rightarrow$ Sortie autorisée vers `cinetrekker-dev-app-sg` sur le port 8080 uniquement.
  * `cinetrekker-dev-app-sg` : Entrée autorisée uniquement depuis `alb-sg` sur le port 8080 $\rightarrow$ Sortie autorisée vers `rds-sg` sur le port 5432, HTTPS 443 pour AWS/S3, UDP/TCP 53 pour le DNS, et HTTP 80 vers l'instance NAT.
  * `cinetrekker-dev-rds-sg` : Entrée autorisée uniquement depuis `app-sg` sur le port 5432 $\rightarrow$ Sortie strictement interdite.
  * `cinetrekker-dev-nat-sg` : Entrée autorisée pour les CIDRs privés `10.0.11.0/24` et `10.0.12.0/24` $\rightarrow$ Sortie `0.0.0.0/0`.
* **Zéro Port d'Administration Ouvert** : Ports 22 (SSH) et 3389 (RDP) fermés sur l'ensemble de l'infrastructure. L'administration à distance s'effectue au moyen d'**AWS Systems Manager (SSM) Session Manager**.

### 1.3 Couche de Calcul Élastique (`modules/calcul`)
* **Application Load Balancer (ALB)** : Point d'accès unique (`cinetrekker-dev-alb`) déployé en frontal dans les sous-réseaux publics 1a et 1b, écoutant sur le port 80.
* **Target Group & Contrôle de Santé** :
  * Cible : Port interne `8080` (HTTP).
  * Contrôle de santé : Route `/health`, code attendu HTTP 200, intervalle de 15 secondes, seuil de santé de 2 succès consécutifs, et délai de déréférencement de 30 secondes pour accélérer l'éviction en cas d'anomalie.
* **Launch Template Multi-AZ** :
  * Image système : Amazon Linux 2023 (`al2023-ami-2023.*-x86_64`).
  * Type d'instance : `t3.micro` (2 vCPU, 1 Go RAM).
  * Profil IAM imposé : `LabInstanceProfile`.
  * Disque racine : 20 Go gp3 chiffré par défaut.
  * Script d'initialisation (`user_data`) entièrement automatisé :
    1. Installation de Node.js, `tar`, `gzip` et de l'agent AWS CloudWatch.
    2. Récupération sécurisée du secret DB depuis l'objet S3 chiffré via l'AWS CLI (aucun mot de passe dans le script).
    3. Génération du fichier d'environnement `/etc/cinetrekker/app.env` avec permissions restrictives (`chmod 600`).
    4. Téléchargement et désarchivage du paquet applicatif `s3://${bucket}/app/cinetrekker.tar.gz`.
    5. Création et activation du service systemd `cinetrekker.service` (redémarrage automatique en 5 secondes en cas de crash).
    6. Démarrage de l'agent CloudWatch collectant `/var/log/user-data.log`.
* **Auto Scaling Group (ASG)** :
  * Capacité : **Minimum 2**, **Désirée 2**, **Maximum 4**.
  * Répartition automatique sur les deux sous-réseaux privés applicatifs (`us-east-1a` et `us-east-1b`).
  * Contrôle de santé configuré sur `ELB` avec période de grâce de 180 secondes.

### 1.4 Base de Données Managée (`modules/base-de-donnees`)
* **Instance Amazon RDS** : Moteur PostgreSQL version 15.13 sur classe `db.t3.micro`.
* **Stockage** : 20 Go gp3 avec chiffrement KMS activé au repos.
* **Sous-réseaux** : `DB Subnet Group` couvrant les deux zones (`us-east-1a` et `us-east-1b`).
* **Gestion des Sauvegardes** : Fenêtre de backup quotidien automatique avec rétention de 1 jour (RPO $\le$ 24h).
* **Décision budgétaire (ADR-03)** : Option Multi-AZ désactivée pour diviser le coût RDS par deux (~0,021 $/h contre ~0,042 $/h).

### 1.5 Stockage d'Artefacts & Secrets (`modules/stockage`)
* **Bucket S3** : `cinetrekker-dev-artifacts-<account_id>` avec chiffrement côté serveur par défaut (SSE-S3 AES-256) et blocage total des accès publics (`aws_s3_bucket_public_access_block`).
* **Secret DB** : Mot de passe maître généré aléatoirement par Terraform (`random_password`) de 16 caractères et téléversé dans `s3://.../secrets/db_password.txt`.
* **Artefact d'Application** : Archive `s3://.../app/cinetrekker.tar.gz` contenant le bundle React compilé et le serveur web `server.js`.

### 1.6 Supervision & Métriques (`modules/supervision`)
* **Log Group CloudWatch** : `/aws/ec2/cinetrekker-dev-app` avec rétention explicite de **1 jour** pour éliminer tout surcoût d'archivage (ADR-06).
* **Dashboard Unifié** : `cinetrekker-dev-supervision-dashboard` affichant 4 graphiques temps réel :
  1. Santé des cibles ALB (`HealthyHostCount` vs `UnHealthyHostCount`).
  2. Charge moyenne CPU de l'ASG (`CPUUtilization` en %).
  3. Volume de requêtes et erreurs HTTP (`RequestCount` et `HTTPCode_Target_5XX_Count`).
  4. Connexions actives sur PostgreSQL (`DatabaseConnections`).
* **Alarmes Métriques** :
  1. `cinetrekker-dev-alarm-unhealthy-hosts` : Déclenchée si `UnHealthyHostCount >= 1` pendant 60 secondes.
  2. `cinetrekker-dev-alarm-high-cpu` : Déclenchée si `CPUUtilization > 70%` pendant 2 périodes consécutives de 60 secondes.

---

## 2. Justification Technique de la Solution d'Accès Sortant (NAT)

L'un des défis majeurs de l'architecture 3-tiers en environnement étudiant réside dans l'accès sortant depuis les sous-réseaux privés (indispensable pour l'installation des dépendances Linux et les appels aux APIs web de métadonnées de films).

### 2.1 Comparatif des Options Envisagées

| Critère d'Évaluation | Option A : AWS Managed NAT Gateway | Option B : Instance NAT EC2 (`t3.micro`) + VPC Endpoint S3 *(Choix Retenu)* | Option C : Sous-réseaux Publics Directs (Sans Tiers Privé) |
| :--- | :--- | :--- | :--- |
| **Coût par heure** | **0,045 USD/h** (+ 0,045 USD/Go traité) | **0,0104 USD/h** (Instance `t3.micro`) | 0,00 USD (Adresses IP publiques directes) |
| **Coût mensuel estimé** | **~32,85 USD / mois** (hors trafic) | **~7,59 USD / mois** (si continu, ~0,03 $ par TP) | 0,00 USD (hors surcoût IPv4 publique AWS) |
| **Consommation du budget 50$** | **> 65% du crédit total consommé** en 1 mois | **< 1% du crédit** par session de TP | 0% |
| **Disponibilité / Résilience** | Haute disponibilité native managée multi-AZ | Nœud unique dans la zone 1a (SPOF documenté) | Dépendant des instances individuelles |
| **Sécurité d'Architecture** | Conforme au modèle 3-tiers étanche | Conforme au modèle 3-tiers étanche | **Non conforme** : instances directement exposées |
| **Charge Réseau Lourde (Artefacts)** | Payante au Go via la passerelle | **Gratuite et directe** grâce au S3 VPC Gateway Endpoint | Directe via Internet Gateway |

### 2.2 Analyse du Compromis Retenu (ADR-01 et ADR-05)
1. **Élimination du Risque Financier** : Déployer un NAT Gateway managé aurait rendu impossible le respect de l'engagement budgétaire (< 35 USD). L'instance NAT réduit la facture horaire de routage de plus de 75%.
2. **Décharge Critique via le S3 Gateway Endpoint** : L'artefact applicatif (`cinetrekker.tar.gz`) et le secret DB représentent le volume de données le plus lourd au démarrage. Grâce au **VPC Gateway Endpoint pour S3** (100% gratuit), ce trafic ne traverse jamais l'instance NAT et circule directement sur l'infrastructure dorsale AWS.
3. **Acceptabilité du Compromis** : L'instance NAT constitue un point unique de défaillance (SPOF) pour le trafic sortant non-S3. Ce compromis est pleinement assumé, formellement documenté dans l'ADR-01, et parfaitement proportionné aux objectifs d'un projet académique.

---

## 3. Fonctionnement du Script de Destruction Automatisée

Le script de destruction (`scripts/destroy.ps1` sous Windows, relayé par le lanceur 1-clic `LANCER_DESTROY_AWS.bat`, ou `scripts/destroy.sh` sous Linux) garantit la suppression intégrale de toutes les ressources facturables à l'heure.

### 3.1 Déroulement Séquentiel Sans Blocage

```mermaid
sequenceDiagram
    autonumber
    actor Etudiant as Étudiant / Démonstrateur
    participant Script as Script destroy.ps1
    participant AWS_CLI as AWS CLI
    participant TF as Terraform Engine
    participant Journal as docs/journal-destructions.md

    Etudiant->>Script: Exécution de destroy.ps1
    Script->>AWS_CLI: 1. Suppression forcée de l'instance RDS
    AWS_CLI-->>Script: Attente active de la libération des interfaces réseau (ENIs)
    Script->>TF: 2. Exécution de terraform destroy -auto-approve
    TF-->>Script: Démantèlement de l'ASG, ALB, NAT, Security Groups, VPC
    Script->>AWS_CLI: 3. Vidage et suppression forcée du bucket S3 (aws s3 rb --force)
    AWS_CLI-->>Script: Bucket d'artefacts supprimé
    Script->>Journal: 4. Consignation automatique de la destruction (date, durée)
    Script-->>Etudiant: Facturation horaire arrêtée à 0,00 USD
```

### 3.2 Inventaire des Éléments Supprimés
1. **Instances et Groupes de Calcul** :
   * Les instances EC2 applicatives et l'instance NAT sont résiliées.
   * L'Auto Scaling Group et le Launch Template sont supprimés.
   * L'Application Load Balancer (ALB), ses règles d'écouteur port 80 et son Target Group port 8080 sont détruits.
2. **Base de Données et Réseau Associé** :
   * L'instance RDS PostgreSQL est arrêtée sans création de snapshot final (`--skip-final-snapshot`) et ses sauvegardes automatisées sont purgées (`--delete-automated-backups`).
   * Les interfaces réseau d'attachement (ENIs) sont libérées avant que Terraform ne tente de supprimer les sous-réseaux, évitant les erreurs de dépendance circulaire (`DependencyViolation`).
   * Le `DB Subnet Group` est retiré.
3. **Réseau Périmétrique et Sécurité** :
   * Le point de terminaison S3 Gateway Endpoint est dissocié et supprimé.
   * Les 4 Security Groups (`alb-sg`, `app-sg`, `rds-sg`, `nat-sg`) sont éliminés.
   * Les associations de tables de routage, les 6 sous-réseaux, l'Internet Gateway et le VPC sont détruits.
4. **Stockage et Supervision** :
   * Le bucket S3 d'artefacts est vidé et supprimé via `aws s3 rb --force`.
   * Le log group CloudWatch, les 2 alarmes métriques et le dashboard unifié sont retirés.

---

## 4. Procédure de Démonstration en Direct (Pas à Pas)

Cette procédure correspond aux commandes exactes du projet pour la soutenance chronométrée de 15 minutes.

### Étape 0 : Préparation des Identifiants (1 minute)
Vérifier que la session AWS Academy est active dans votre terminal :
```powershell
aws sts get-caller-identity
```
*Le résultat doit afficher le compte `766734107199` et le rôle `LabRole`.*

---

### Étape 1 : Préparation du Paquet Applicatif (Automatique ou Manuelle)
Si le paquet n'a pas encore été généré :
```powershell
cd app
npm run build
tar -czf cinetrekker.tar.gz dist server.js package.json
cd ..
```

---

### Étape 2 : Déploiement en Une Seule Commande (Livrable Clé)
Exécuter le script orchestrateur depuis la racine du dépôt :
```powershell
.\LANCER_DEPLOY_AWS.bat
```
*(Ou directement dans PowerShell : `.\scripts\deploy.ps1`)*

**Ce que réalise le script sous les yeux de l'enseignant** :
1. Valide l'existence de l'archive `app/cinetrekker.tar.gz`.
2. Initialise Terraform (`terraform init`).
3. Vérifie et crée de manière idempotente le bucket S3 selon les règles de conformité AWS Academy.
4. Applique l'infrastructure (`terraform apply -auto-approve`).
5. Affiche le temps total mesuré (< 15 minutes) ainsi que les URLs publiques.

---

### Étape 3 : Vérifications en Direct Devant l'Enseignant (3 minutes)

1. **Accessibilité Web & Contrôle de Santé** :
   * Ouvrir dans le navigateur :
     ```text
     http://<ALB_DNS_NAME>
     ```
   * Vérifier l'endpoint de contrôle de santé :
     ```text
     http://<ALB_DNS_NAME>/health
     ```
     *(Réponse attendue : `{"status":"ok","app":"cinetrekker","service":"cinetrekker-web",...}`)*

2. **Répartition de Charge Multi-AZ** :
   * Actualiser la page plusieurs fois (F5) et observer le badge d'infrastructure indiquant l'alternance des instances entre les zones `us-east-1a` et `us-east-1b`.

3. **Supervision Temps Réel (CloudWatch)** :
   * Ouvrir la console AWS CloudWatch $\rightarrow$ **Dashboards** $\rightarrow$ `cinetrekker-dev-supervision-dashboard`.
   * Montrer les 4 graphiques actifs : cibles ALB saines (2 cibles vertes), CPU nominal (< 10%), requêtes reçues et connexions PostgreSQL.

---

### Étape 4 : Démonstration de Résilience et Tolérance de Panne (3 minutes)

1. Dans un premier terminal, générer un flux de requêtes continues :
   ```powershell
   python scripts/load_test.py --url http://<ALB_DNS_NAME> --users 20 --duration 60
   ```
2. Dans un second terminal, injecter une terminaison brutale d'instance :
   ```powershell
   python scripts/chaos_inject.py terminate
   ```
3. **Résultat immédiat sous les yeux du professeur** :
   * L'application web continue de répondre sur le navigateur sans interruption (0 erreur 5xx) grâce à la seconde instance.
   * L'alarme `cinetrekker-dev-alarm-unhealthy-hosts` s'active sur CloudWatch.
   * L'Auto Scaling Group détecte la cible manquante et instancie automatiquement une nouvelle machine de remplacement en moins de 5 minutes.

---

### Étape 5 : Destruction Propre et Arrêt de la Facturation (2 minutes)
À la fin de la soutenance, lancer la destruction en un clic :
```powershell
.\LANCER_DESTROY_AWS.bat
```
*(Ou dans PowerShell : `.\scripts\destroy.ps1`)*

Vérifier que toutes les ressources facturées à l'heure sont détruites et que la mention d'arrêt de facturation est consignée dans `docs/journal-destructions.md`.

---

## 5. Plans de Secours (Plan B en Cas d'Imprévu Pendant la Démo)

| Scénario d'Incident | Cause Racine Probable | Procédure de Résolution Immédiate (Plan B) |
| :--- | :--- | :--- |
| **1. Erreur d'authentification `ExpiredToken` lors de `terraform apply`** | La session AWS Academy STS (4h) a expiré juste avant ou pendant le TP. | 1. Aller sur AWS Academy Learner Lab $\rightarrow$ Cliquer sur **AWS Details** $\rightarrow$ **Show Credentials**.<br>2. Copier le nouveau bloc dans `~/.aws/credentials`.<br>3. Relancer la commande sans détruire l'état Terraform : `terraform apply -auto-approve`. |
| **2. Cibles ALB affichées "Unhealthy" dans les premières minutes** | Le script `user_data` de démarrage est encore en train de compiler ou d'installer les dépendances (période de grâce). | 1. Rappeler au professeur que la période d'initialisation de l'instance requiert 90 à 120 secondes.<br>2. Examiner les logs d'amorçage via la commande SSM ou CloudWatch Logs (`/aws/ec2/cinetrekker-dev-app`).<br>3. Les cibles basculent à l'état `Healthy` dès le premier succès sur `/health`. |
| **3. Erreur Terraform `DependencyViolation` sur un sous-réseau lors de `destroy`** | Une interface réseau élastique (ENI) d'ALB ou de RDS est en cours de libération lente par AWS. | 1. Ne pas paniquer : le script `destroy.ps1` intègre une boucle de rattrapage automatique.<br>2. Si nécessaire, relancer uniquement `.\scripts\destroy.ps1` qui supprimera les résidus une fois l'ENI détachée par AWS. |
| **4. Panne réseau ou problème de connectivité sur l'instance NAT** | Le flag `source_dest_check` n'a pas été désactivé ou `iptables` n'est pas encore actif. | 1. Noter que le trafic S3 n'est pas impacté car il emprunte le **VPC Gateway Endpoint direct**.<br>2. Redémarrer l'instance NAT depuis la console ou via `aws ec2 reboot-instances --instance-ids <nat_instance_id>`. |
| **5. Dépassement strict du temps imparti (limite de 15 minutes)** | Temps insuffisant pour attendre la création complète de la base de données RDS (6 à 8 min). | 1. Basculer immédiatement sur la présentation de la documentation technique pré-enregistrée.<br>2. Ouvrir le document de preuves horodatées `docs/mesures-preuves.md` et les captures d'écran de CloudWatch montrant les métriques réelles obtenues lors des essais précédents. |
