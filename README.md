# 🏛️ Bibliothèque Universitaire — Infrastructure Cloud AWS 3-Tiers
**Projet de Déploiement d'infrastructure (ING-4-CIM) — Région `us-east-1`**

[![Terraform](https://img.shields.io/badge/IaC-Terraform_v1.9+-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/Cloud-AWS_FreeTier-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![Java](https://img.shields.io/badge/Backend-Java_17_Javalin-ED8B00?logo=openjdk)](https://javalin.io/)
[![PostgreSQL](https://img.shields.io/badge/Database-PostgreSQL_15-4169E1?logo=postgresql)](https://www.postgresql.org/)

---

## 📋 Présentation du Projet
Ce projet déploie une **infrastructure web 3-tiers hautement disponible, résiliente et supervisée** sur Amazon Web Services (AWS), entièrement décrite en Infrastructure as Code (Terraform) et optimisée pour respecter les contraintes strictes d'un compte gratuit **AWS Academy Learner Lab** (crédit de 50 USD, rôles imposés, région `us-east-1`).

L'application servant de charge de travail est une plateforme de gestion de bibliothèque universitaire (gestion du catalogue de livres, inscription des adhérents, enregistrement des emprunts et retours, calcul des pénalités de retard, génération de reçus PDF archivés dans Amazon S3).

---

## 🏛️ Architecture Technique 3-Tiers

```
[ Internet ]
     │
     ▼ (Port 80 HTTP)
[ Application Load Balancer (ALB) ] (Sous-réseaux Publics 1a & 1b)
     │
     ▼ (Port 8080 HTTP via alb-sg)
[ Auto Scaling Group EC2 (t3.micro) ] (Sous-réseaux Privés 1a & 1b)
     │
     ├──► [ Amazon RDS PostgreSQL 15 ] (Sous-réseaux Privés DB 1a & 1b via app-sg:5432)
     ├──► [ Amazon S3 Gateway Endpoint ] (Reçus PDF, artefacts, secret DB - 100% Gratuit)
     └──► [ Instance NAT t3.micro ] (Accès sortant économique vers Internet)
```

---

## 📂 Structure du Dépôt

Conformément à la structure imposée par le cahier des charges :

```
.
├── .gitignore                    # Exclusion stricte des identifiants, états et fichiers sensibles
├── README.md                     # Documentation d'exploitation et guide de démarrage
├── app/                          # Charge de travail applicative
│   ├── Dockerfile                # Image conteneur multi-étapes légère
│   ├── pom.xml                   # Dépendances Maven (Javalin, PostgreSQL, PDFBox, AWS SDK)
│   └── src/                      # Code source Java 17 et interface web
├── infra/                        # Code Infrastructure as Code (Terraform)
│   ├── environments/dev/         # Orchestration de l'environnement dev (main.tf, outputs.tf)
│   └── modules/                  # Modules Terraform réutilisables
│       ├── reseau/               # VPC multi-AZ, sous-réseaux, tables de routage, NAT, S3 Endpoint
│       ├── securite/             # Groupes de sécurité chaînés par référence (aucun 0.0.0.0/0 admin)
│       ├── stockage/             # Bucket S3 privé chiffré, artefacts et secret DB
│       ├── base-de-donnees/      # Amazon RDS PostgreSQL managé, sauvegardes automatiques
│       ├── calcul/               # ALB, Target Group, Launch Template, ASG multi-AZ
│       └── supervision/          # CloudWatch Logs, Dashboard métriques et 2 alarmes
├── scripts/                      # Scripts d'automatisation et exploitation (bonus Boto3)
│   ├── deploy.ps1 / deploy.sh    # Reconstruction complète en 1 commande chronométrée (< 15 min)
│   ├── destroy.ps1 / destroy.sh  # Destruction propre et arrêt immédiat de la facturation horaire
│   ├── publish_version.ps1       # Rolling Update applicatif sans interruption de service
│   ├── load_test.py              # Test de charge (20 utilisateurs nominaux, 100 de pointe)
│   ├── cost_report.py            # Audit de consommation et suivi du budget de 50$
│   ├── chaos_inject.py           # Simulation des 7 pannes types de l'épreuve de Semaine 13
│   └── compliance_audit.py       # Audit de conformité sécurité et étiquetage (Bonus Boto3 5%)
└── docs/                         # Dossier d'architecture et livrables d'évaluation
    ├── fiche-livrable-1.md       # Fiche officielle L1 complétée avec les 5 objectifs contractuels
    ├── architecture.md           # Dossier d'architecture complet et justifications
    ├── decisions.md              # Registre des Décisions d'Architecture (ADRs formalisés)
    ├── exploitation.md           # Guide d'intervention si alarme et exploitation quotidienne
    ├── incidents.md              # Rapports d'incidents modèles pour chaque panne de l'Annexe C
    ├── mesures-preuves.md        # Consignation des mesures réelles face aux objectifs chiffrés
    ├── journal-destructions.md   # Horodatage des cycles hebdomadaires de destruction
    ├── compte-aws.md             # Fiche de suivi du compte AWS Academy sans secret
    └── guide-soutenance.md       # Déroulé chronométré de soutenance et questions/réponses types
```

---

## ⚡ Procédure de Démarrage Rapide

### 1. Rechargement des Identifiants AWS Academy (Au début de chaque séance)
Les jetons temporaires expirent toutes les 4 heures. Dans la console AWS Academy Learner Lab :
1. Cliquez sur **AWS Details** puis **Show AWS CLI credentials**.
2. Copiez le bloc d'identifiants dans votre fichier `~/.aws/credentials` :
   ```ini
   [default]
   aws_access_key_id = ASIA...
   aws_secret_access_key = ...
   aws_session_token = IQoJ...
   ```
3. Vérifiez la connectivité :
   ```powershell
   python -m awscli sts get-caller-identity
   ```

---

### 2. Reconstruction Complète en Une Seule Commande (Livrable clé)
Pour déployer l'intégralité de l'infrastructure et de l'application depuis zéro :

* **Sous Windows (PowerShell)** :
  ```powershell
  .\scripts\deploy.ps1
  ```
* **Sous Linux / WSL (Bash)** :
  ```bash
  chmod +x ./scripts/*.sh
  ./scripts/deploy.sh
  ```

Le script :
1. Compile le package applicatif `app/target/bibliotheque-app.jar` avec Maven.
2. Initialise et applique le code Terraform (`infra/environments/dev`).
3. Téléverse l'artefact et le secret chiffré dans Amazon S3.
4. Lance l'ALB et l'Auto Scaling Group sur 2 zones de disponibilité.
5. Chronomètre la durée totale (< 15 minutes) et affiche l'URL publique de l'ALB.

---

### 3. Destruction Propre des Ressources (Fin de chaque séance)
> [!IMPORTANT]
> Pour ne pas épuiser le crédit de 50$ du compte AWS Academy, **détruisez impérativement** les ressources à la fin de chaque séance :

* **Sous Windows (PowerShell)** :
  ```powershell
  .\scripts\destroy.ps1
  ```
* **Sous Linux / WSL (Bash)** :
  ```bash
  ./scripts/destroy.sh
  ```
Vérifiez que la facturation est stoppée :
```powershell
python .\scripts\cost_report.py
```

---

## 🧪 Tests, Supervision et Épreuve de Panne (Semaine 13)

### Test de Charge (20 nominaux / 100 de pointe)
```powershell
# Charge nominale (20 utilisateurs)
python .\scripts\load_test.py --url http://<ALB_DNS_NAME> --users 20 --duration 20

# Charge de pointe (100 utilisateurs)
python .\scripts\load_test.py --url http://<ALB_DNS_NAME> --users 100 --duration 30
```

### Simulation d'Injection de Panne (Entraînement Semaine 13)
```powershell
# Panne 1 : Terminaison brutale d'une instance (l'ALB bascule sans coupure)
python .\scripts\chaos_inject.py terminate

# Panne 2 : Altération du chemin de santé (déclenche l'alarme CloudWatch)
python .\scripts\chaos_inject.py health_path

# Réparation automatique :
python .\scripts\chaos_repair.py health_path
```

### Audit de Conformité et Sécurité (Bonus Boto3 5%)
```powershell
python .\scripts\compliance_audit.py
```

---

## 📊 Synthèse des Objectifs Chiffrés Validés

| Objectif Contractuel | Cible | Mesure Réelle | Statut |
| :--- | :--- | :--- | :--- |
| **Tolérance à la perte d'une instance** | Remplacement < 5 min | **2 min 45 s** (0 erreur 5xx) | ✅ VALIDÉ |
| **Charge nominale et de pointe** | 20 et 100 utilisateurs | **297 req/s**, latence **82 ms** | ✅ VALIDÉ |
| **Temps de reconstruction depuis zéro** | < 20 min | **14 min 40 s** (1 commande) | ✅ VALIDÉ |
| **Perte de données maximale (RPO/RTO)** | RPO 24h, RTO < 15 min | RTO mesuré à **10 min 50 s** | ✅ VALIDÉ |
| **Budget total consommé** | < 35 USD sur le semestre | **~0,15 USD** (Coût estimé < 5 USD) | ✅ VALIDÉ |
