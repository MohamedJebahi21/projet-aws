#!/usr/bin/env python3
"""
Script de remise en état / remédiation après incident (Chaos Engineering).
Restaure la configuration saine pour chaque scénario de panne.
"""

import sys
import argparse
import boto3

def get_clients():
    session = boto3.session.Session(region_name="us-east-1")
    return (
        session.client("ec2"),
        session.client("elbv2"),
        session.client("autoscaling"),
        session.client("s3")
    )

def repair_health_path():
    _, elbv2, _, _ = get_clients()
    print("[RÉPARATION] Restauration du chemin de santé de l'ALB...")
    tgs = elbv2.describe_target_groups()
    matching = [tg for tg in tgs.get("TargetGroups", []) if "biblio-dev" in tg["TargetGroupName"]]
    if not matching: return
    tg_arn = matching[0]["TargetGroupArn"]

    elbv2.modify_target_group(
        TargetGroupArn=tg_arn,
        HealthCheckPath="/health"
    )
    print("✅ Réparation terminée : HealthCheckPath restauré à '/health'. Les cibles vont redevenir saines.")

def repair_cut_db_sg():
    ec2, _, _, _ = get_clients()
    print("[RÉPARATION] Restauration de la règle d'accès réseau RDS...")
    rds_sgs = ec2.describe_security_groups(Filters=[{"Name": "group-name", "Values": ["biblio-dev-rds-sg"]}])
    app_sgs = ec2.describe_security_groups(Filters=[{"Name": "group-name", "Values": ["biblio-dev-app-sg"]}])
    if not rds_sgs.get("SecurityGroups") or not app_sgs.get("SecurityGroups"):
        print("❌ SGs introuvables.")
        return

    rds_sg_id = rds_sgs["SecurityGroups"][0]["GroupId"]
    app_sg_id = app_sgs["SecurityGroups"][0]["GroupId"]

    try:
        ec2.authorize_security_group_ingress(
            GroupId=rds_sg_id,
            IpPermissions=[{
                "IpProtocol": "tcp",
                "FromPort": 5432,
                "ToPort": 5432,
                "UserIdGroupPairs": [{"GroupId": app_sg_id}]
            }]
        )
        print("✅ Réparation terminée : Règle d'accès PostgreSQL (5432) réactivée depuis l'application.")
    except Exception as e:
        print(f"Règle déjà présente ou erreur : {e}")

def repair_all():
    print("Exécution de la réparation globale de l'infrastructure...")
    repair_health_path()
    repair_cut_db_sg()
    print("✅ Réparation globale exécutée. Vérifiez /health sur l'ALB.")

def main():
    parser = argparse.ArgumentParser(description="Remédiation des pannes injectées")
    parser.add_argument("scenario", choices=["health_path", "cut_db", "all"], default="all", nargs="?",
                        help="Scénario à réparer (défaut: all)")
    args = parser.parse_args()

    if args.scenario == "health_path":
        repair_health_path()
    elif args.scenario == "cut_db":
        repair_cut_db_sg()
    else:
        repair_all()

if __name__ == "__main__":
    main()
