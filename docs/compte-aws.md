# FICHE DE VÉRIFICATION DU COMPTE AWS ET DES CONTRAINTES
**AWS Academy Learner Lab — Environnement d'évaluation**

---

## 1. Caractéristiques de l'Environnement
* **Type d'environnement** : AWS Academy Learner Lab (compte éducatif temporaire).
* **Crédit initial alloué** : 50,00 USD par étudiant pour l'ensemble du semestre (14 semaines).
* **Région unique imposée** : `us-east-1` (Virginie du Nord).
* **Rôle d'exécution imposé** : `arn:aws:iam::<ACCOUNT_ID>:role/LabRole`.
* **Profil d'instance EC2 imposé** : `LabInstanceProfile`.
* **Gestion des sessions** : Sessions limitées à 4 heures consécutives, renouvelables. Les identifiants temporaires (`aws_session_token`) changent à chaque reconnexion.

---

## 2. État de Vérification du Compte (Maintenu à jour)

| Élément vérifié | Résultat du test | Commentaire / Statut |
| :--- | :--- | :--- |
| **Authentification STS** | **VALIDÉ** | Rôle `assumed-role/voclabs/user...` opérationnel |
| **Région AWS** | **VALIDÉ** | Toutes les ressources déclarées en `us-east-1` |
| **Création VPC & IGW** | **VALIDÉ** | Quota disponible (5 VPCs max, 1 utilisé) |
| **Instances EC2 t3.micro** | **VALIDÉ** | Quota suffisant pour 3 instances (2 ASG + 1 NAT) |
| **Application Load Balancer** | **VALIDÉ** | Création et Target Group autorisés |
| **Amazon RDS PostgreSQL** | **VALIDÉ** | Moteur PostgreSQL 15 `db.t3.micro` disponible |
| **Amazon S3** | **VALIDÉ** | Création de buckets privés et chiffrement SSE-S3 autorisés |
| **CloudWatch Dashboard & Alarmes** | **VALIDÉ** | Alarmes métriques créées sans restriction de quota |

---

## 3. Stratégie de Prévention de Rupture de Compte (Failover)
* En cas d'épuisement imprévu du crédit du compte porteur principal, le groupe déclenche immédiatement la procédure de bascule documentée :
  1. Export du state Terraform distant ou ré-application directe depuis le dépôt Git.
  2. Remplacement des identifiants `~/.aws/credentials` par ceux du Compte Étudiant 2.
  3. Lancement de `scripts/deploy.ps1` sur le nouveau compte. L'infrastructure se recrée à l'identique en moins de 15 minutes.
