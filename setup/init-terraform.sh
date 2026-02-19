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

TFSTATE_BUCKET=$(jq -r .tfstate_bucket "$DOMAIN_JSON")
REGION=$(jq -r .aws_region "$DOMAIN_JSON")

if [[ -z "${TFSTATE_BUCKET}" || "${TFSTATE_BUCKET}" == "null" ]]; then
    echo "ERROR: 'tfstate_bucket' not set in domain.json" >&2
    echo "       Add e.g. \"tfstate_bucket\": \"f01-tfstate\" to domain.json" >&2
    exit 1
fi

echo "Tfstate bucket prefix: ${TFSTATE_BUCKET}"
echo "AWS region:            ${REGION}"
echo ""

for ENV in dev int prod; do
    BUCKET="${TFSTATE_BUCKET}-${ENV}"
    CONF="${PROJECT_ROOT}/infrastructure/environments/${ENV}/backend.conf"
    cat > "${CONF}" <<EOF
# Auto-generated from domain.json - run setup/init-terraform.sh to regenerate.
bucket         = "${BUCKET}"
region         = "${REGION}"
use_lockfile   = true
EOF
    echo "Generated: infrastructure/environments/${ENV}/backend.conf  (bucket: ${BUCKET})"
done

echo ""
echo "IMPORTANT: make sure the S3 buckets exist before running terraform init."
echo "See setup/README.md for instructions on creating them."
echo ""
echo "Run 'terraform init -backend-config=backend.conf' in each environment directory."
