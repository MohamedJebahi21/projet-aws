# LIVRABLE 1 : CAHIER DES CHARGES ET SPÉCIFICATIONS FONCTIONNELLES
**Projet et Déploiement d'Infrastructure Cloud AWS (3-Tiers)**
*Établissement : TEK-UP — Promotion ING-4 (Module ING-4-CIM)*  
*Enseignant responsable : Hamdi Chebbi*

---

## 1. Sujet et Contexte du Projet

### 1.1 Contexte Académique
Ce projet s'inscrit dans le cadre du module d'ingénierie **"Projet et Déploiement" (ING-4-CIM)** à l'école **TEK-UP**. L'objectif fondamental est de concevoir, déployer, sécuriser et superviser une infrastructure Web complète en architecture **3-tiers hautement disponible** sur le cloud public **Amazon Web Services (AWS)**.

L'évaluation porte principalement sur la rigueur de l'**Infrastructure as Code (IaC)**, la résilience aux pannes, la maîtrise des réseaux et de la sécurité périmétrique, ainsi que la stricte optimisation budgétaire imposée par l'environnement académique.

### 1.2 Identification du Projet
* **Titre du projet** : Déploiement Résilient d'une Infrastructure Web 3-Tiers pour la Plateforme CineTrekker
* **Dépôt Git** : `[À COMPLÉTER]` (ex. *https://github.com/votre-compte/projet-aws-cinetrekker-3tiers*)
* **Membres de l'équipe (5 étudiants)** :
  * **JEBAHI Mohamed** (Lead Développeur Applicatif & Intégration Cloud)
  * **LAAMERI Mohamed** (Lead Cloud Architect & IaC Terraform Réseau/Calcul)
  * **KAHLA Salma** (Ingénieure Sécurité Cloud & Persistance des Données)
  * **CHAIBI Arij** (Ingénieure DevOps & Automatisation Déploiement/Destruction)
  * **KHARRAT Mouheddin** (Ingénieur Supervision, Observabilité SRE & Qualité)
* **Compte porteur désigné** : Compte principal AWS Academy (`766734107199` / rôle `LabRole`).
* **Ordre de bascule (failover budget)** : Compte Mohamed Jebahi $\rightarrow$ Compte Mohamed Laameri $\rightarrow$ Compte Salma Kahla $\rightarrow$ Compte Arij Chaibi $\rightarrow$ Compte Mouheddin Kharrat.

---

## 2. Application Retenue : CineTrekker

### 2.1 Description Fonctionnelle
La charge de travail applicative déployée sur l'infrastructure est **CineTrekker**, une plateforme web cinéphile moderne dédiée à l'exploration, au suivi de visionnage et à la recommandation personnalisée de films et séries télévisées.

### 2.2 Fonctionnalités Principales
1. **Exploration et Recherche Multi-Critères** :
   * Navigation par tendances hebdomadaires/quotidiennes, genres, notes et dates de sortie.
   * Recherche instantanée de films, séries, acteurs et réalisateurs via un proxy d'API externe (The Movie Database - TMDB).
2. **Fiches Détaillées Riches** :
   * Affichage des métadonnées cinématographiques : synopsis, casting, bandes-annonces vidéo intégrées, notes critiques et saisons/épisodes.
3. **Suivi Personnel & Bibliothèque Cinéphile** :
   * Gestion de listes personnalisées (*Watchlist*, *Déjà vu*, *Favoris*).
   * Suivi fin des épisodes vus par saison (mode connecté avec persistance et mode invité avec sauvegarde locale).
4. **Contrôle Opérationnel & Santé Système** :
   * Endpoint applicatif `/health` dédié, retournant l'état du service, le temps de fonctionnement (*uptime*), le nom de l'hôte et la date pour les contrôles de santé du Load Balancer.
   * Proxy interne d'API `/api/tmdb-proxy` évitant les blocages CORS et sécurisant les requêtes sortantes vers les APIs partenaires.

---

## 3. Composants Déduits du Code Source

L'analyse exhaustive du code source (`app/`, `infra/`, `scripts/`) permet d'identifier l'agencement suivant :

```mermaid
flowchart LR
    Front["Front-End SPA<br/>(React 19 / Vite)"]
    Back["Back-End / Serveur HTTP<br/>(Node.js ESM :8080)"]
    DB[("Base de Données<br/>(PostgreSQL 15 RDS)"]
    S3[("Stockage Objet<br/>(S3 Privé Chiffré)"]
    Sup["Supervision<br/>(CloudWatch Logs & Metrics)"]

    Front --> Back
    Back --> DB
    Back --> S3
    Back --> Sup
```

### 3.1 Front-End
* **Technologies** : React 19, TypeScript, Vite, Tailwind CSS, Radix UI.
* **Caractéristiques** : Single Page Application (SPA) compilée sous forme d'actifs statiques optimisés (`app/dist/`), incluant le découpage de bundle (*code splitting*) et la mise en cache immuable des médias et polices.

### 3.2 Back-End / Serveur Web Applicatif
* **Technologies** : Node.js (moteur natif ESM sans dépendance d'exécution superflue, `app/server.js`).
* **Fonctions clés** :
  * Écoute sur le port réseau interne `8080`.
  * Routage SPA avec fallback vers `index.html`.
  * Endpoint de supervision `/health` répondant avec code HTTP 200 JSON.
  * Point de passage d'API sécurisé `/api/tmdb-proxy`.
  * Service systemd Linux (`cinetrekker.service`) assurant le redémarrage automatique en cas de crash.

### 3.3 Base de Données
* **Moteur** : Amazon RDS PostgreSQL version 15.13 (`db.t3.micro`).
* **Stockage** : 20 Go gp3 chiffré au repos (AES-256).
* **Isolation** : Placé dans des sous-réseaux privés dédiés sans aucune adresse IP publique ni route vers Internet.

### 3.4 Infrastructure d'Hébergement & Réseau
* **Réseau** : VPC dédié `10.0.0.0/16` découpé en 6 sous-réseaux répartis sur 2 Zones de Disponibilité (`us-east-1a` et `us-east-1b`).
* **Entrée & Répartition** : 1 Application Load Balancer (ALB) public exposant le port 80.
* **Calcul élastique** : Auto Scaling Group (ASG) configuré pour maintenir entre 2 et 4 instances EC2 `t3.micro` (Amazon Linux 2023).
* **Accès Sortant** : 1 instance NAT EC2 `t3.micro` avec translation d'adresse `iptables-nft` pour les instances privées.
* **Liaison Directe S3** : Point de terminaison d'accès VPC Gateway Endpoint pour Amazon S3.

### 3.5 Stockage d'Artefacts & Secrets
* **Amazon S3** : Bucket privé chiffré SSE-S3 (`cinetrekker-dev-artifacts-<account_id>`) hébergeant l'archive d'application `cinetrekker.tar.gz` et le secret de connexion à la base de données (`secrets/db_password.txt`).

### 3.6 Supervision & Observabilité
* **Amazon CloudWatch** : Log group avec rétention d'un jour, tableau de bord unifié (4 graphiques temps réel) et 2 alarmes métriques de détection d'anomalie.

---

## 4. Objectifs et Contraintes du Projet

### 4.1 Contraintes Académiques et Techniques Imposées
1. **Plafond Budgétaire Strict (50 USD)** :
   * Chaque étudiant dispose d'un crédit unique non renouvelable de 50 USD sur AWS Academy Learner Lab.
   * Aucune ressource payante ne doit être laissée en fonctionnement en dehors des séances d'évaluation.
2. **Environnement AWS Academy Learner Lab** :
   * Région géographique unique imposée : `us-east-1` (Virginie du Nord).
   * Rôles IAM verrouillés : interdiction formelle de créer des rôles IAM personnalisés (`iam:CreateRole` interdit par les SCPs). L'infrastructure doit impérativement employer le profil existant `LabInstanceProfile` et le rôle `LabRole`.
   * Politiques SCP (Service Control Policies) restrictives interdisant certaines APIs (comme `s3:GetBucketObjectLockConfiguration` ou `autoscaling:StartInstanceRefresh`).
   * Jetons d'authentification temporaires STS à renouveler toutes les 4 heures.
3. **Infrastructure as Code (IaC) Intégrale** :
   * 100% des ressources doivent être définies et déployées par Terraform.
   * Interdiction absolue de créer ou modifier des ressources manuellement via la console AWS.

---

### 4.2 Objectifs Non-Fonctionnels Contractuels (Tableau d'Engagements)

| N° | Objectif Non-Fonctionnel | Cible Chiffrée Engagée | Mode de Vérification et Démonstration |
| :---: | :--- | :--- | :--- |
| **1** | **Tolérance à la panne d'instance** | Zéro interruption de service (0 erreur 5xx) ; remplacement d'instance défaillante en **< 5 minutes**. | Terminaison brutale d'une instance EC2 via console ou script (`scripts/chaos_inject.py`) sous flux de requêtes HTTP actif. |
| **2** | **Capacité de charge** | **Nominale : 20 utilisateurs simultanés**.<br>**Pointe : 100 utilisateurs simultanés** (> 150 req/s, latence < 150 ms). | Script de test de charge multi-thread (`scripts/load_test.py`) avec visualisation live sur le dashboard CloudWatch. |
| **3** | **Temps de reconstruction complète** | **< 20 minutes** (de l'état zéro jusqu'à l'application opérationnelle). | Exécution chronométrée sans intervention de `scripts/deploy.ps1`. |
| **4** | **Perte de données maximale (RPO/RTO)** | **RPO $\le$ 24 heures** (sauvegardes automatiques) ;<br>**RTO < 15 minutes**. | Restauration d'une instance RDS depuis un snapshot de sauvegarde suite à une altération simulée. |
| **5** | **Plafond de consommation financière** | **< 35 USD consommés** sur le semestre (marge de sécurité de 15 USD). | Suivi hebdomadaire dans le journal des destructions (`docs/journal-destructions.md`) et destruction après chaque session. |

---

## 5. Synthèse des Livrables Documentaires

* **Livrable 1 (L1)** : Présent document de cadrage, spécifications fonctionnelles et engagements (`docs/L1_cahier_des_charges.md`).
* **Livrable 2 (L2)** : Dossier d'architecture technique détaillé, schéma Mermaid fidèle au code, matrice de justification à 5 axes et estimation budgétaire (`docs/L2_architecture.md`).
* **Livrable 3 (L3)** : Rapport technique d'infrastructure IaC, justification du routage NAT, explication du cycle de vie/destruction et déroulé pas à pas de la soutenance (`docs/L3_infrastructure.md`).
