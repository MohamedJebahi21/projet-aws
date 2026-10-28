# GUIDE DE SOUTENANCE ORALE ET DÉMONSTRATION EN DIRECT
**Projet de Déploiement d'infrastructure AWS (ING-4-CIM)**

---

## 1. Déroulé Chronométré de la Soutenance (15 à 20 minutes)

| Temps | Phase | Contenu & Actions en direct |
| :--- | :--- | :--- |
| **00:00 - 03:00** | **1. Présentation de l'Architecture** | - Présentation du schéma 3-tiers (VPC, ALB, ASG multi-AZ, RDS PostgreSQL, S3, CloudWatch).<br>- Rappel des contraintes du Learner Lab (50$, rôles LabRole, us-east-1). |
| **03:00 - 06:00** | **2. Démonstration Applicative** | - Connexion à l'URL publique de l'ALB.<br>- Démonstration de l'alternance des requêtes entre `us-east-1a` et `us-east-1b` visible sur le badge de zone.<br>- Création d'un prêt avec génération de reçu PDF archivé dans S3. |
| **06:00 - 09:00** | **3. Épreuve de Résilience (Live Failure)** | - Lancement du script de flux continu : `python scripts/load_test.py --users 20`.<br>- Terminaison brutale d'une instance EC2 via `python scripts/chaos_inject.py terminate`.<br>- Constat : **Zéro interruption de service**, l'ALB bascule instantanément, l'ASG recrée une VM. |
| **09:00 - 12:00** | **4. Supervision & Alarmes** | - Affichage du tableau de bord unifié CloudWatch en direct.<br>- Démonstration de l'alarme `cinetrekker-dev-alarm-unhealthy-hosts` ou `high-cpu`. |
| **12:00 - 15:00** | **5. Reproductibilité & Destruction** | - Lancement de `scripts/destroy.ps1` : démonstration de la suppression complète.<br>- Preuve du temps de reconstruction chronométré (< 15 min). |
| **15:00 - 20:00** | **6. Questions / Réponses avec le Jury** | - Défense des décisions d'architecture et justification des choix techniques. |

---

## 2. Questions Fréquentes du Jury et Réponses Clés

#### Q1 : Pourquoi avoir choisi une instance NAT EC2 plutôt qu'un NAT Gateway managé AWS ?
> **Réponse** : "Le NAT Gateway managé est facturé ~0,045 $/h (~32 $/mois), ce qui aurait épuisé 65% de notre crédit de 50$ en un seul mois. Nous avons déployé une micro-instance EC2 `t3.micro` avec `iptables`, combinée à un VPC Gateway Endpoint S3 gratuit. Cela divise le coût par 4 tout en assurant l'accès sortant requis pour les instances privées."

#### Q2 : Comment garantissez-vous qu'aucun secret ne figure dans Git ni dans le User Data ?
> **Réponse** : "Le mot de passe de la base de données est généré aléatoirement par Terraform (`random_password`), puis directement écrit dans un objet S3 chiffré (`secrets/db_password.txt`). Au démarrage, l'instance EC2 utilise son profil de rôle `LabInstanceProfile` pour télécharger le secret et l'injecter dans un fichier d'environnement local protégé avec les permissions `chmod 600`. Aucun mot de passe n'est écrit dans le code source ni dans les données utilisateur."

#### Q3 : Que se passe-t-il exactement si une zone de disponibilité d'Amazon tombe en panne ?
> **Réponse** : "Notre architecture est déployée sur deux zones (`us-east-1a` et `us-east-1b`). L'ALB détecte l'échec des contrôles de santé sur les cibles de la zone sinistrée en moins de 30 secondes et réachemine 100% des requêtes vers la seconde zone. L'Auto Scaling Group rétablit ensuite automatiquement le nombre d'instances désiré sur la zone opérationnelle."

#### Q4 : Pourquoi le Multi-AZ de la base RDS est-il désactivé ?
> **Réponse** : "Le Multi-AZ sur RDS double immédiatement le coût horaire de l'instance de base. Pour respecter notre budget cible de 35$ sur tout le semestre, nous avons privilégié une configuration Single-AZ en sous-réseau privé avec des sauvegardes quotidiennes automatisées et des snapshots manuels, offrant un RPO de 24 heures et un RTO de moins de 11 minutes."

#### Q5 : Comment garantissez-vous que l'état Terraform ne sera pas perdu entre plusieurs étudiants ?
> **Réponse** : "L'état Terraform peut être stocké dans un bucket S3 privé chiffré dédié. De plus, notre code d'infrastructure est 100% déterministe et reproductible : en cas de changement de compte porteur, une seule commande `deploy.ps1` recrée l'intégralité de l'environnement depuis zéro sans aucune étape manuelle."

#### Q6 : Comment prouvez-vous que vous n'avez pas cliqué dans la console AWS ?
> **Réponse** : "Toutes les ressources portent le tag `ManagedBy = Terraform` et le préfixe normalisé `cinetrekker-dev`. La destruction complète puis la reconstruction de bout en bout en une seule commande en moins de 15 minutes démontre que 100% de notre infrastructure est définie en code versionné."
