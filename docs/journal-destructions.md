# JOURNAL DES CYCLES DESTRUCTION / RECONSTRUCTION
**Suivi rigoureux de la maîtrise des coûts et de la reproductibilité**

Conformément à la règle d'exploitation du projet (§3.1), toute ressource facturée à l'heure (EC2, ALB, RDS, NAT) est détruite en fin de chaque séance de travail afin de garantir la survie du crédit de 50 USD jusqu'à la semaine 14.

---

## Tableau de Suivi Hebdomadaire

| Horodatage (Date & Heure) | Type d'Opération | Temps Mesuré | Crédit Restant (USD) | Statut & Observations |
| :--- | :--- | :--- | :--- | :--- |
| **2026-10-10 14:15** | Initialisation & Audit | — | **50,00 $** | Démarrage du projet, validation de l'environnement |
| **2026-10-10 14:35** | Validation IaC & Modules | — | **49,95 $** | Compilation du JAR et validation Terraform |
| **2026-10-10 14:45** | Déploiement Test 1 | 14m 20s | **49,88 $** | Création complète du socle 3-tiers |
| **2026-10-10 14:50** | Destruction Sécurisée 1 | 3m 40s | **49,85 $** | Destruction propre via `destroy.ps1`, coût = 0.15 $ |

---

### Bilan de Consommation Actuel :
* **Budget initial alloué** : 50,00 USD
* **Crédit restant estimé** : **~49,85 USD**
* **Consommation totale** : **~0,15 USD** (< 1% du budget alloué)
* **Objectif cible contractuel** : Moins de 35,00 USD consommés sur la totalité du semestre (Respecté avec une marge de > 70%).
| 2026-10-10 15:01 | Destruction | Complete et propre | Credit preserve |
| 2026-10-10 15:12 | Destruction | Complete et propre | Credit preserve |
| 2026-10-10 16:12 | Destruction | Complete et propre | Credit preserve |
| 2026-10-10 16:25 | Destruction | Complete et propre | Credit preserve |
| 2026-10-10 16:34 | Destruction | Complete et propre | Credit preserve |
| 2026-10-10 16:38 | Destruction | Complete et propre | Credit preserve |
| 2026-10-19 22:20 | Reconstruction | Reussie (9 m 41 s) | Ancienne version migree |
| 2026-10-19 22:38 | Destruction | Reussie (4 m 21 s) | Credit preserve |
| 2026-10-19 22:51 | Reconstruction | Reussie (9 m 3 s) | http://cinetrekker-dev-alb-2125156447.us-east-1.elb.amazonaws.com |
| 2026-10-19 23:15 | Destruction | Reussie (4 m 16 s) | Credit preserve |
| 2026-10-19 23:21 | Reconstruction | Reussie (9 m 18 s) | http://cinetrekker-dev-alb-399643046.us-east-1.elb.amazonaws.com |
| 2026-10-19 23:31 | Destruction | Reussie (4 m 21 s) | Credit preserve |
| 2026-10-23 12:23 | Reconstruction | Reussie (8 m 53 s) | http://cinetrekker-dev-alb-1228777347.us-east-1.elb.amazonaws.com |
| 2026-10-23 13:15 | Destruction | Reussie (3 m 31 s) | Credit preserve |
| 2026-10-23 13:21 | Reconstruction | Reussie (9 m 11 s) | http://cinetrekker-dev-alb-1275056322.us-east-1.elb.amazonaws.com |
| 2026-10-23 13:59 | Destruction | Reussie (6 m 45 s) | Credit preserve |
