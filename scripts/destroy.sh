#!/usr/bin/env bash
# ========================================================
# Script Bash de destruction propre des ressources facturées
# ========================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/../infra/environments/dev"

echo "=========================================================="
echo "   DESTRUCTION DES RESSOURCES FACTURÉES À L'HEURE (AWS)   "
echo "=========================================================="
echo "Démarrage : $(date)"

cd "$TF_DIR"
terraform destroy -auto-approve

echo "=========================================================="
echo "   DESTRUCTION TERMINÉE ! FACTURATION STOPPÉE."
echo "=========================================================="

# Nettoyage et suppression propre du bucket S3
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text | tr -d '\r\n')
BUCKET_NAME="biblio-dev-artifacts-${ACCOUNT_ID}"
echo "Nettoyage du bucket S3 ($BUCKET_NAME)..."
aws s3 rb "s3://$BUCKET_NAME" --force 2>/dev/null || true

JOURNAL="$SCRIPT_DIR/../docs/journal-destructions.md"
if [ -f "$JOURNAL" ]; then
    echo "| $(date '+%Y-%m-%d %H:%M') | Destruction | Complète et propre | Crédit préservé |" >> "$JOURNAL"
fi

echo -e "\n>>> PENSEZ À RELEVER LE CRÉDIT RESTANT DANS LE LEARNER LAB <<<"
