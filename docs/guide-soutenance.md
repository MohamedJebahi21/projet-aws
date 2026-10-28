# GUIDE DE SOUTENANCE ORALE (15 MINUTES CHRONO)
**Module ING-4-CIM — Enseignant responsable : Hamdi Chebbi**
*Évaluation officielle : Livrables L1, L2 et L3*

---

## ⏱️ Répartition du Temps (15 Minutes — 5 Étudiants)

Le professeur a précisé dans son mail :  
> *« 15 minutes par groupe, avec la participation de tous les membres. »*

Voici la répartition idéale de 3 minutes par étudiant :

---

### 1. Mohamed JEBAHI (0:00 – 3:00) : Livrable L1
* **Document à projeter** : [`docs/L1_cahier_des_charges.md`](file:///C:/Users/DELL/OneDrive/Desktop/ING-4/Project/projet/docs/L1_cahier_des_charges.md)
* **Ce qu'il faut dire** :
  * Présentation du sujet : plateforme web CineTrekker.
  * Application retenue : SPA moderne développée en React 19 / TypeScript / Vite, servie par Node.js sur le port 8080.
  * Composants applicatifs : Front-end réactif, serveur HTTP avec route de santé `/health` et proxy d'API TMDB.
  * Présentation du dépôt Git et des 5 rôles de l'équipe.

---

### 2. Mohamed LAAMERI (3:00 – 6:00) : Livrable L2 (Architecture & Réseau)
* **Document à projeter** : [`docs/L2_architecture.md`](file:///C:/Users/DELL/OneDrive/Desktop/ING-4/Project/projet/docs/L2_architecture.md) (Schéma Mermaid)
* **Ce qu'il faut dire** :
  * Découpage réseau : VPC dédié `10.0.0.0/16` sur 2 Zones de Disponibilité (`us-east-1a` et `us-east-1b`).
  * 6 sous-réseaux : 2 publics (ALB et NAT), 2 privés applicatifs (instances EC2), et 2 sous-réseaux isolés (préparés pour la persistance L5).
  * Point d'entrée unique par l'Application Load Balancer (ALB) sur le port 80 distribuant le trafic vers le port 8080 des instances.
  * Justification sur les axes **Disponibilité** (multi-AZ) et **Scalabilité** (Auto Scaling Group élastique).

---

### 3. Salma KAHLA (6:00 – 9:00) : Livrable L2 (Sécurité & Stockage)
* **Document à projeter** : [`docs/L2_architecture.md`](file:///C:/Users/DELL/OneDrive/Desktop/ING-4/Project/projet/docs/L2_architecture.md) (Matrice de Sécurité)
* **Ce qu'il faut dire** :
  * Principe du moindre privilège : chaînage strict des Security Groups (`alb-sg` $\rightarrow$ `app-sg` $\rightarrow$ `nat-sg`) sans aucune adresse IP en dur.
  * Zéro port d'administration ouvert : aucun port SSH 22 ou RDP 3389 exposé sur Internet. Administration exclusive via AWS Systems Manager (SSM) Session Manager.
  * Stockage S3 : bucket privé chiffré SSE-S3 AES-256 avec accès public 100% bloqué pour héberger l'archive applicative `cinetrekker.tar.gz`.

---

### 4. Arij CHAIBI (9:00 – 12:00) : Livrable L3 (Accès Sortant NAT & Démo Live)
* **Document à projeter** : [`docs/L3_infrastructure.md`](file:///C:/Users/DELL/OneDrive/Desktop/ING-4/Project/projet/docs/L3_infrastructure.md) + Terminal
* **Ce qu'il faut dire et montrer** :
  * **Justification de l'accès sortant (ADR-01)** : Pourquoi une instance NAT `t3.micro` avec `iptables-nft` (~0,0104 $/h) au lieu d'un NAT Gateway managé AWS à 0,045 $/h (~32,85 $/mois qui consommerait 65% du budget étudiant).
  * Rôle clé du **VPC Gateway Endpoint S3 (100% gratuit)** : le téléchargement du package lourd ne passe pas par l'instance NAT.
  * **Démonstration Live** :
    1. Ouvrir le navigateur sur `http://<ALB_DNS>`.
    2. Ouvrir `http://<ALB_DNS>/health` (HTTP 200 OK).
    3. Montrer l'alternance des instances entre les 2 zones en faisant F5.

---

### 5. Mouheddin KHARRAT (12:00 – 15:00) : Livrable L2/L3 (Budget & Destruction)
* **Document à projeter** : [`docs/journal-destructions.md`](file:///C:/Users/DELL/OneDrive/Desktop/ING-4/Project/projet/docs/journal-destructions.md) + Exécution `destroy.ps1`
* **Ce qu'il faut dire et montrer** :
  * Estimation financière : coût horaire réel de **~0,06 USD/h** (~0,18 $ par TP de 3h).
  * **Rappel du professeur dans son mail** : *"une semaine d'oubli consomme environ 35 % du crédit de 50 USD"*. Mouheddin montre le calcul exact : $13,81 \text{ USD} \approx 28\% \text{ à } 35\%$ du budget si l'on oublie de détruire.
  * **Lancement de la destruction en direct** devant le professeur : double-clic sur `LANCER_DESTROY_AWS.bat` (ou `destroy.ps1`).
  * Montrer que l'infrastructure se démonte proprement en moins de 60 secondes sans blocage, stoppant net toute facturation horaire.
