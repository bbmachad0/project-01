#!/usr/bin/env bash
# ─── Generate Terraform backend config files from domain.json ────
# Run this after changing domain.json to regenerate backend.conf
# for all environments.
#
# Usage:  ./setup/init-terraform.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOMAIN_JSON="${PROJECT_ROOT}/domain.json"

if [[ ! -f "${DOMAIN_JSON}" ]]; then
    echo "ERROR: domain.json not found at ${DOMAIN_JSON}" >&2
    exit 1
fi

ABBR=$(python3 -c "import json; print(json.load(open('${DOMAIN_JSON}'))['domain_abbr'])")
REGION=$(python3 -c "import json; print(json.load(open('${DOMAIN_JSON}'))['aws_region'])")

echo "Domain abbreviation: ${ABBR}"
echo "AWS region:          ${REGION}"
echo ""

for ENV in dev int prod; do
    CONF="${PROJECT_ROOT}/infrastructure/environments/${ENV}/backend.conf"
    cat > "${CONF}" <<EOF
# Auto-generated from domain.json — run setup/init-terraform.sh to regenerate.
bucket         = "${ABBR}-tfstate-${ENV}"
region         = "${REGION}"
dynamodb_table = "${ABBR}-tflock-${ENV}"
EOF
    echo "Generated: infrastructure/environments/${ENV}/backend.conf"
done

echo ""
echo "Run 'terraform init -backend-config=backend.conf' in each environment directory."
