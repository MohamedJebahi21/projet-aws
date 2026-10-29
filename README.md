# CineTrekker — Infrastructure Cloud AWS (Livrables L1, L2, L3)
**Plateforme de Découverte de Films & Séries — Déploiement Cloud Résilient (us-east-1)**

[![Terraform](https://img.shields.io/badge/IaC-Terraform_v1.9+-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/Cloud-AWS_Learner_Lab-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![React](https://img.shields.io/badge/Frontend-React_19_Vite-61DAFB?logo=react)](https://react.dev/)
[![NodeJS](https://img.shields.io/badge/Runtime-Node.js_20-339933?logo=node.js)](https://nodejs.org/)
[![Dépôt Git](https://img.shields.io/badge/GitHub-MohamedJebahi21%2Fprojet--aws-blue?logo=github)](https://github.com/MohamedJebahi21/projet-aws)

---

## 📋 Présentation du Projet
Ce projet déploie une **infrastructure web hautement disponible, résiliente et sécurisée** sur Amazon Web Services (AWS), entièrement décrite en **Infrastructure as Code (Terraform)** et optimisée pour respecter les contraintes strictes d'un compte **AWS Academy Learner Lab** (crédit de 50 USD, rôles imposés `LabRole`/`LabInstanceProfile`, région `us-east-1`).

L'application servant de charge de travail est **CineTrekker**, une plateforme web cinéphile moderne (React 19 / TypeScript / Vite / Node.js) dédiée à l'exploration, au suivi de séries et à la découverte de films.

### Équipe de Projet (5 Étudiants — TEK-UP / Promotion ING-4 / Module ING-4-CIM)
* **JEBAHI Mohamed** : Lead Développeur Applicatif & Intégration Cloud (`mohamed.jebahi21@gmail.com`)
* **LAAMERI Mohamed** : Lead Cloud Architect & IaC Terraform Réseau/Calcul (`lamerimohamed870@gmail.com`)
* **KAHLA Salma** : Ingénieure Sécurité Cloud & Données (`salmabenkahla40@gmail.com`)
* **CHAIBI Arij** : Ingénieure DevOps & Automatisation CI/CD (`arijchaibi51@gmail.com`)
* **KHARRAT Mouheddin** : Ingénieur Supervision & Qualité SRE (`Mohidinemoha5@gmail.com`)

---

## 🏛️ Architecture Technique Déployée par IaC

```text
[ Internet / Utilisateurs ]
       │
       ▼ (Port 80 HTTP)
[ Application Load Balancer (ALB) ] (Sous-réseaux Publics 1a & 1b)
       │
       ▼ (Port 8080 HTTP via alb-sg)
[ Auto Scaling Group EC2 (t3.micro) ] (Sous-réseaux Privés 1a & 1b - CineTrekker Node.js)
       │
       ├──► [ Amazon S3 Gateway Endpoint ] (Artefacts cinetrekker.tar.gz - 100% Gratuit)
       └──► [ Instance NAT t3.micro ] (Accès sortant économique vers Internet avec iptables)
```

---

## 📂 Structure du Dépôt

```text
.
├── LANCER_DEPLOY_AWS.bat         # Batch Windows 1-Clic : Déploiement complet en < 3m30s
├── LANCER_DESTROY_AWS.bat        # Batch Windows 1-Clic : Destruction totale en < 3 min ($0.00)
├── README.md                     # Documentation d'exploitation et guide de démarrage
├── app/                          # Charge de travail applicative CineTrekker
│   ├── dist/                     # Bundle React 19 / Vite optimisé
│   ├── server.js                 # Serveur HTTP Node.js natif (port 8080, route /health)
│   ├── cinetrekker.tar.gz        # Archive déployée sur les instances EC2 privées
│   └── src/                      # Code source TypeScript / React
├── infra/                        # Code Infrastructure as Code (Terraform)
│   ├── environments/dev/         # Orchestration de l'environnement dev (main.tf, outputs.tf)
│   └── modules/                  # Modules Terraform réutilisables
│       ├── reseau/               # VPC multi-AZ, 6 sous-réseaux, tables de routage, NAT, S3 Endpoint
│       ├── securite/             # Groupes de sécurité chaînés par référence (aucun 0.0.0.0/0 admin)
│       ├── stockage/             # Bucket S3 privé chiffré SSE-S3 AES-256 pour l'archive
│       └── calcul/               # ALB public, Target Group /health, Launch Template, ASG multi-AZ
├── scripts/                      # Scripts d'automatisation et exploitation
│   ├── deploy.ps1 / deploy.sh    # Reconstruction complète chronométrée (< 3 minutes 30s)
│   ├── destroy.ps1 / destroy.sh  # Destruction propre et arrêt immédiat de la facturation horaire
│   └── publish_version.ps1       # Rolling Update applicatif sans interruption de service
└── docs/                         # Documentation officielle et livrables d'évaluation
    ├── Cahier_des_Charges_CineTrekker.docx       # Cahier des charges unifié officiel (L1, L2, L3)
    ├── Presentation_Soutenance_CineTrekker.pptx  # Support officiel de soutenance orale (15 min)
    └── journal-destructions.md                   # Journal chronométré des déploiements et destructions
```

---

## ⚡ Procédure d'Exploitation

### 1. Rechargement des Identifiants AWS Academy (Début de séance)
1. Ouvrez AWS Academy Learner Lab et cliquez sur **Start Lab**.
2. Cliquez sur **AWS Details** puis **Show AWS CLI credentials**.
3. Copiez le bloc dans `~/.aws/credentials` :
   ```ini
   [default]
   aws_access_key_id = ASIA...
   aws_secret_access_key = ...
   aws_session_token = IQoJ...
   ```
4. Vérifiez la connectivité :
   ```powershell
   aws sts get-caller-identity
   ```

---

### 2. Reconstruction Complète en Une Seule Commande (Livrables L1-L3)
Depuis la racine du projet, lancez :

* **Sous Windows** : Double-cliquez sur `LANCER_DEPLOY_AWS.bat` ou exécutez dans PowerShell :
  ```powershell
  .\scripts\deploy.ps1
  ```
* **Sous Linux / WSL** :
  ```bash
  chmod +x ./scripts/*.sh
  ./scripts/deploy.sh
  ```

**Durée totale mesurée (séance du 28/10/2026)** : **3 min 26 s** (l'application et le Target Group sont opérationnels immédiatement).  
Le script affiche l'URL publique de l'ALB : `http://<ALB_DNS>` et la route de santé : `http://<ALB_DNS>/health`.

---

### 3. Destruction Propre des Ressources (Fin de chaque séance)
Pour arrêter immédiatement la facturation horaire et préserver le crédit de 50 USD :

* **Sous Windows** : Double-cliquez sur `LANCER_DESTROY_AWS.bat` ou exécutez :
  ```powershell
  .\scripts\destroy.ps1
  ```
* **Sous Linux / WSL** :
  ```bash
  ./scripts/destroy.sh
  ```

**Durée totale mesurée** : **2 min 59 s** pour la destruction complète de l'ensemble des 18 ressources AWS.
