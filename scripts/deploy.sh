#!/usr/bin/env bash
# ========================================================
# Script Bash de déploiement et reconstruction chronométrée
# ========================================================
set -e

START_TIME=$(date +%s)
echo "=========================================================="
echo "   RECONSTRUCTION COMPLETE EN UNE SEULE COMMANDE (AWS)   "
echo "=========================================================="
echo "Démarrage : $(date)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/../app"
TF_DIR="$SCRIPT_DIR/../infra/environments/dev"

# 1. Compilation si JAR absent
if [ ! -f "$APP_DIR/target/bibliotheque-app.jar" ]; then
    echo -e "\n[1/4] Compilation du package JAR avec Maven..."
    (cd "$APP_DIR" && mvn clean package -DskipTests)
else
    echo -e "\n[1/4] Artefact JAR présent."
fi

# 2. Terraform Init & Apply
echo -e "\n[2/4] Initialisation Terraform..."
cd "$TF_DIR"
terraform init

# Vérification et création idempotente du bucket S3 (conforme SCPs AWS Academy)
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text | tr -d '\r\n')
BUCKET_NAME="biblio-dev-artifacts-${ACCOUNT_ID}"
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo -e "\nPréparation du bucket S3 conforme AWS Academy ($BUCKET_NAME)..."
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region us-east-1 >/dev/null
fi

echo -e "\n[3/4] Déploiement de l'infrastructure..."
terraform apply -auto-approve

# 3. Mesure du temps
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

APP_URL=$(terraform output -raw application_url 2>/dev/null || echo "N/A")
HEALTH_URL=$(terraform output -raw healthcheck_url 2>/dev/null || echo "N/A")

echo "=========================================================="
echo "   DÉPLOIEMENT TERMINÉ AVEC SUCCÈS !"
echo "=========================================================="
echo "Temps mesuré       : ${MINUTES}m ${SECONDS}s"
echo "URL Application    : $APP_URL"
echo "Contrôle de santé  : $HEALTH_URL"

# Journalisation
JOURNAL="$SCRIPT_DIR/../docs/journal-destructions.md"
if [ -f "$JOURNAL" ]; then
    echo "| $(date '+%Y-%m-%d %H:%M') | Reconstruction | Réussie (${MINUTES}m ${SECONDS}s) | $APP_URL |" >> "$JOURNAL"
fi
