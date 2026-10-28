# REGISTRE DES DÉCISIONS D'ARCHITECTURE (ADR)
**Architecture 3-Tiers AWS — Plateforme CineTrekker**

---

### ADR-01 : Choix d'une Instance NAT EC2 plutôt qu'un NAT Gateway managé
* **Statut** : Validé (à faire approuver formellement par l'enseignant).
* **Contexte** : Les instances applicatives situées en sous-réseaux privés ont besoin d'accéder à Internet pour télécharger des paquets Linux et contacter certaines API AWS publiques non couvertes par un endpoint de gateway.
* **Option A** : AWS Managed NAT Gateway (0,045 $/h + trafic = ~32,40 $/mois).
* **Option B** : Instance EC2 NAT minimale `t3.micro` avec `iptables` (~0,0104 $/h = ~7,50 $/mois si continu, et ~0,03 $ par séance de 3h).
* **Décision** : **Option B retenue.** Le NAT Gateway managé épuiserait plus de 60% du budget de 50$ en quelques semaines. L'instance NAT est entièrement provisionnée par IaC avec `source_dest_check = false` et un script de masquerading automatique.
* **Conséquences / Limitations** : L'instance NAT constitue un point unique de défaillance (SPOF) pour le trafic sortant non-S3. Ce compromis est pleinement documenté et acceptable dans le cadre d'un compte étudiant gratuit.

---

### ADR-02 : Mécanisme de Gestion des Secrets via Objet S3 Chiffré
* **Statut** : Validé (à faire approuver formellement par l'enseignant).
* **Contexte** : L'exigence stricte §5.2 stipule qu'aucun secret ne doit apparaître en clair dans le dépôt Git, ni dans son historique, ni dans les données utilisateur (`user_data`) du Launch Template.
* **Option A** : AWS Secrets Manager (non inclus dans la liste gratuite, 0,40 $/secret/mois).
* **Option B** : Stockage du secret généré par Terraform dans un objet Amazon S3 privé chiffré (`s3://${bucket}/secrets/db_password.txt`), récupéré par le script de démarrage via `LabInstanceProfile`.
* **Décision** : **Option B retenue.** Le rôle IAM `LabRole` possède déjà les autorisations de lecture S3. Le mot de passe de la base RDS est injecté directement dans `/etc/library/app.env` avec des droits `chmod 600` et n'apparaît jamais dans les logs ni dans la console EC2.

---

### ADR-03 : Moteur PostgreSQL 15 et Désactivation du Multi-AZ RDS
* **Statut** : Validé.
* **Contexte** : Une persistance relationnelle managée est requise par le cahier des charges.
* **Décision** : Moteur **PostgreSQL 15** sur instance `db.t3.micro` (stockage 20 Go gp3 chiffré). L'option Multi-AZ est **désactivée**.
* **Justification** : Le mode Multi-AZ double la facturation horaire de RDS (~0,036 $/h contre ~0,018 $/h). Pour respecter le budget cible de 35$ sur le semestre, le Multi-AZ RDS est désactivé, la résilience des données étant assurée par les sauvegardes automatiques quotidiennes et les snapshots ponctuels (RPO de 24h respecté).

---

### ADR-04 : Transformation de l'Application JavaFX Desktop en Web REST Stateless
* **Statut** : Validé.
* **Contexte** : L'application existante (`mmm (1)`) était un client lourd de bureau JavaFX exploitant SQLite en fichier local.
* **Problèmes identifiés** :
  1. Pas de serveur d'affichage X11 sur les instances EC2 Linux du Learner Lab.
  2. Impossibilité pour un ALB d'acheminer du trafic web vers une fenêtre JavaFX.
  3. Fichier SQLite local incompatible avec une architecture multi-instances (données non synchronisées entre instances).
* **Décision** : Enrobage de la logique métier (modèles, règles d'emprunts) dans une application Web légère avec **Javalin** (embarque Jetty) et une interface HTML5/CSS/JS monopage.
* **Bénéfices** : Démarrage ultra-rapide (< 3 secondes), consommation mémoire minime (< 120 Mo de RAM, idéale pour `t3.micro`), compatibilité native avec le health check ALB (`/health`), et migration transparente vers PostgreSQL.

---

### ADR-05 : Utilisation du VPC Gateway Endpoint pour Amazon S3
* **Statut** : Validé.
* **Contexte** : Les instances applicatives transfèrent des reçus PDF et des artefacts vers Amazon S3.
* **Décision** : Mise en place d'un `aws_vpc_endpoint` de type `Gateway` pour Amazon S3 rattaché aux tables de routage publique et privée.
* **Bénéfices** : Le trafic S3 ne traverse ni l'Internet Gateway ni l'instance NAT. Il reste sur le réseau dorsal AWS interne, est 100% gratuit, offre une latence minimale et fonctionne même si l'instance NAT est arrêtée.

---

### ADR-06 : Durée de Rétention des Logs CloudWatch à 1 Jour
* **Statut** : Validé.
* **Contexte** : CloudWatch facture l'ingestion et le stockage des logs au-delà du quota gratuit de 5 Go.
* **Décision** : Rétention explicite configurée à **1 jour** sur le groupe de logs `/aws/ec2/cinetrekker-dev-app`.
* **Justification** : Suffisant pour diagnostiquer les incidents et soutenances de séance, tout en éliminant tout risque de surcoût cumulé sur le semestre.
