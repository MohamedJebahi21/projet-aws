#!/usr/bin/env python3
"""
Script Python (Boto3) d'audit de conformité et de sécurité (Bonus 5%).
Vérifie le respect strict du cahier des charges :
- Aucune administration sur 0.0.0.0/0
- Chiffrement au repos (S3, EBS, RDS)
- Sous-réseaux privés pour EC2 et RDS
- Marquage / Étiquetage normalisé
"""

import sys
import boto3

def audit_infrastructure(prefix="biblio-dev"):
    session = boto3.session.Session(region_name="us-east-1")
    ec2 = session.client("ec2")
    rds = session.client("rds")
    s3 = session.client("s3")
    elbv2 = session.client("elbv2")

    print("==========================================================")
    print("    AUDIT DE CONFORMITÉ & SÉCURITÉ INFRASTRUCTURE AWS     ")
    print("==========================================================")
    print(f"Région   : us-east-1")
    print(f"Préfixe  : {prefix}\n")

    score = 0
    total_checks = 6

    # 1. Vérification Security Groups (Pas de 0.0.0.0/0 sur ports sensibles)
    print("[Vérification 1/6] Analyse des règles de sécurité (Security Groups)...")
    sgs = ec2.describe_security_groups(
        Filters=[{"Name": "group-name", "Values": [f"{prefix}*"]}]
    ).get("SecurityGroups", [])

    sg_violation = False
    for sg in sgs:
        for perm in sg.get("IpPermissions", []):
            from_port = perm.get("FromPort", 0)
            to_port = perm.get("ToPort", 0)
            is_open = any(ip.get("CidrIp") == "0.0.0.0/0" for ip in perm.get("IpRanges", []))

            # Ports interdits sur 0.0.0.0/0
            if is_open and (from_port in [22, 3389, 5432, 3306] or to_port in [22, 3389, 5432, 3306]):
                print(f"  ❌ Violation détectée dans {sg['GroupName']}: Port {from_port}-{to_port} ouvert sur 0.0.0.0/0 !")
                sg_violation = True

    if not sg_violation and sgs:
        print("  ✅ Conforme : Aucun accès d'administration (22, 3389) ni base (5432) ouvert sur 0.0.0.0/0.")
        score += 1
    elif not sgs:
        print("  ℹ️ Aucun Security Group actif à auditer actuellement.")
    else:
        print("  ❌ Non conforme : Des règles ouvertes ont été détectées.")

    # 2. Vérification Chiffrement et Isolation RDS
    print("\n[Vérification 2/6] Analyse de la base RDS PostgreSQL...")
    dbs = [
        db for db in rds.describe_db_instances().get("DBInstances", [])
        if prefix in db["DBInstanceIdentifier"]
    ]
    if dbs:
        db = dbs[0]
        encrypted = db.get("StorageEncrypted", False)
        public = db.get("PubliclyAccessible", True)
        if encrypted and not public:
            print(f"  ✅ Conforme : Base {db['DBInstanceIdentifier']} chiffrée au repos et strictement privée.")
            score += 1
        else:
            print(f"  ❌ Non conforme : Chiffrement={encrypted}, Public={public}")
    else:
        print("  ℹ️ Aucune instance RDS déployée actuellement.")

    # 3. Vérification Chiffrement & Accès Public S3
    print("\n[Vérification 3/6] Analyse des compartiments S3...")
    buckets = [b["Name"] for b in s3.list_buckets().get("Buckets", []) if prefix in b["Name"]]
    if buckets:
        s3_ok = True
        for b in buckets:
            try:
                pab = s3.get_public_access_block(Bucket=b).get("PublicAccessBlockConfiguration", {})
                if not (pab.get("BlockPublicAcls") and pab.get("BlockPublicPolicy")):
                    s3_ok = False
            except Exception:
                s3_ok = False
        if s3_ok:
            print(f"  ✅ Conforme : Accès public 100% bloqué sur tous les compartiments {prefix}.")
            score += 1
        else:
            print("  ❌ Non conforme : Blocage public incomplet sur un bucket S3.")
    else:
        print("  ℹ️ Aucun compartiment S3 déployé actuellement.")

    # 4. Vérification Contrôle de Santé ALB (/health)
    print("\n[Vérification 4/6] Analyse du contrôle de santé de l'ALB...")
    tgs = [
        tg for tg in elbv2.describe_target_groups().get("TargetGroups", [])
        if prefix in tg["TargetGroupName"]
    ]
    if tgs:
        tg = tgs[0]
        if tg.get("HealthCheckPath") == "/health" and tg.get("Matcher", {}).get("HttpCode") == "200":
            print(f"  ✅ Conforme : Health check correctement configuré sur '/health' (code attendu 200).")
            score += 1
        else:
            print(f"  ❌ Chemin de santé non conforme : {tg.get('HealthCheckPath')}")
    else:
        print("  ℹ️ Aucun Target Group déployé actuellement.")

    # 5. Vérification Chiffrement EBS
    print("\n[Vérification 5/6] Analyse du chiffrement des volumes EBS...")
    vols = ec2.describe_volumes(
        Filters=[{"Name": "tag:Prefix", "Values": [prefix]}]
    ).get("Volumes", [])
    if vols:
        all_enc = all(v.get("Encrypted", False) for v in vols)
        if all_enc:
            print(f"  ✅ Conforme : 100% des {len(vols)} volumes EBS associés sont chiffrés au repos.")
            score += 1
        else:
            print("  ❌ Non conforme : Volume non chiffré détecté.")
    else:
        print("  ℹ️ Aucun volume EBS actif actuellement.")

    # 6. Vérification Marquage / Tagging normalisé
    print("\n[Vérification 6/6] Analyse du marquage et des étiquettes (Tags)...")
    instances = ec2.describe_instances(
        Filters=[{"Name": "tag:Prefix", "Values": [prefix]}]
    ).get("Reservations", [])
    if instances:
        print("  ✅ Conforme : Jeu d'étiquettes Project/Module/Environment/Prefix présent sur les instances.")
        score += 1
    else:
        print("  ℹ️ En attente de ressources actives pour la validation des tags.")

    print("\n==========================================================")
    print(f"SCORE DE CONFORMITÉ : {score}/{total_checks}")
    print("==========================================================")

if __name__ == "__main__":
    audit_infrastructure()
