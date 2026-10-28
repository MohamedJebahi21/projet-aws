# LIVRABLE 1 : FICHE DE SUJET ET EXIGENCES
**Projet de Déploiement d'infrastructure AWS — Module ING-4-CIM**
**Enseignant responsable : Hamdi Chebbi**

---

## 1. Identification
* **Titre du projet** : Déploiement Résilient d'une Infrastructure Web 3-Tiers pour la Plateforme CineTrekker
* **Membres du groupe (5 étudiants)** :
  * **JEBAHI Mohamed** (Lead Développeur Applicatif & Intégration Cloud)
  * **LAAMERI Mohamed** (Lead Cloud Architect & IaC Terraform Réseau/Calcul)
  * **KAHLA Salma** (Ingénieure Sécurité Cloud & Persistance des Données)
  * **CHAIBI Arij** (Ingénieure DevOps & Automatisation Déploiement/Destruction)
  * **KHARRAT Mouheddin** (Ingénieur Supervision, Observabilité SRE & Qualité)
* **Dépôt Git** : `projet-aws-cinetrekker-3tiers` (Dépôt Git local versionné avec arborescence normalisée)
* **Compte porteur désigné** : Compte principal AWS Academy (`766734107199`), rôle assumé `LabRole`.
* **Ordre de bascule (failover budget)** : Compte Mohamed Jebahi -> Compte Mohamed Laameri -> Compte Salma Kahla -> Compte Arij Chaibi -> Compte Mouheddin Kharrat.

---

## 2. Description du sujet
* **Domaine métier et problème traité** :
  Plateforme web moderne de découverte, suivi et recommandation de films et séries (catalogue dynamique, fiches détaillées, bandes-annonces, recherche multi-critères, listes de visionnage personnalisées). La plateforme offre un accès web continu et fluide aux cinéphiles même en cas de panne matérielle d'une zone de disponibilité.
* **Application servant de charge de travail** :
  Application web monopage moderne développée en React 19 / TypeScript / Vite, servie par un serveur Node.js optimisé en architecture Web 3-tiers stateless hautement disponible avec route de santé (`/health`).
* **Composants applicatifs et rôle de chacun** :
  * **Front-end** : Interface Web monopage réactive (React 19 / TypeScript / Vite / Tailwind UI) avec mode sombre, carrousels, filtres et lecteur de bandes-annonces.
  * **Back-end / Serveur Web** : Serveur HTTP Node.js natif léger gérant le routage SPA, la compression, les contrôles de santé (`/health`) et l'accès sécurisé aux données.
  * **Base de données** : Amazon RDS PostgreSQL managé en sous-réseau privé multi-AZ garantissant la persistance relationnelle et l'intégrité transactionnelle.
  * **Stockage Objet** : Amazon S3 pour l'archivage chiffré des artefacts applicatifs (`cinetrekker.tar.gz`) et des secrets d'infrastructure.

---

## 3. Objectifs non fonctionnels auto-imposés (Contractuels)

| Objectif | Cible fixée par le groupe | Mode de démonstration validé |
| :--- | :--- | :--- |
| **1. Tolérance à la perte d'une instance applicative** | Continuité de service 100% sans erreur 5xx ; remplacement automatique en **< 5 minutes**. | Terminaison manuelle en direct d'une instance EC2 sur la console ou via script Boto3 pendant un flux continu de requêtes HTTP. |
| **2. Charge nominale et charge de pointe visées** | Nominale : **20 utilisateurs simultanés**.<br>Pointe : **100 utilisateurs simultanés** (débit > 150 req/s, latence moyenne < 150 ms). | Script Python de test de charge multi-thread (`scripts/load_test.py`) avec observation en direct sur le dashboard CloudWatch. |
| **3. Temps de reconstruction complet de l'infrastructure** | **< 20 minutes** (de zéro jusqu'à l'application en ligne prête). | Destruction complète puis exécution de `scripts/deploy.ps1` chronométrée en direct sans intervention manuelle. |
| **4. Perte de données maximale admissible (RPO)** | **24 heures** (sauvegardes automatiques quotidiennes) ; **RTO < 15 minutes**. | Démonstration de création de snapshot RDS, altération d'une table, et restauration d'une instance RDS depuis le snapshot. |
| **5. Budget total consommé sur le semestre** | **< 35 USD** sur les 50 USD alloués par étudiant. | Suivi strict par relevé hebdomadaire (`docs/journal-destructions.md`) et destruction systématique des ressources facturées à l'heure. |

---

## 4. Faisabilité préliminaire
* **Services de la liste §4.1 mobilisés** :
  * `IAM` (`LabRole` et `LabInstanceProfile` imposés par AWS Academy Learner Lab).
  * `VPC`, sous-réseaux (2 publics, 2 privés applicatifs, 2 privés DB), tables de routage, Internet Gateway.
  * `Security Groups` chaînés par référence (ALB -> App -> RDS, NAT).
  * `EC2` (`t3.micro`) pour les instances applicatives et l'instance NAT.
  * `EBS gp3` chiffré pour les disques racines.
  * `Application Load Balancer (ALB)` avec health checks `/health`.
  * `Auto Scaling Group` + `Launch Template` multi-AZ (us-east-1a et us-east-1b).
  * `Amazon RDS PostgreSQL` (`db.t3.micro`) chiffré, backups automatiques.
  * `Amazon S3` (bucket d'artefacts et reçus PDF, accès public bloqué).
  * `Amazon CloudWatch` (Log groups, Dashboard unifié, 2 alarmes actives).
* **Solution d'accès sortant retenue (§5.3)** :
  * **Choix validé** : Instance NAT minimale (`t3.micro`) en sous-réseau public configurée par `iptables`, combinée à un **VPC Gateway Endpoint pour S3** (gratuit).
  * **Justification** : Le NAT Gateway managé AWS est facturé 0,045 $/heure (~32,40 $/mois), ce qui consommerait 65% du crédit de 50$ en un seul mois. L'instance NAT ne coûte que ~0,0104 $/heure et est détruite après chaque séance.
* **Points de risque identifiés et stratégies de mitigation** :
  1. *Épuisement du crédit AWS Academy* : Résolu par script de destruction automatique `scripts/destroy.ps1` exécuté à la fin de chaque séance.
  2. *Expiration des jetons de session STS (toutes les 4 heures)* : Procédure documentée de rechargement des variables d'environnement sans commit.
  3. *Impossibilité de créer des rôles IAM personnalisés* : Utilisation systématique de `LabRole` et `LabInstanceProfile`. Sécurité déplacée au niveau réseau (Security Groups étanches) et stockage (chiffrement S3/EBS/RDS).
