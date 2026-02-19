#!/usr/bin/env bash
# ─── Generate Terraform backend config files ─────────────────────
# Reads domain.json for the region and resolves the AWS Account ID
# from the current credentials to build the backend bucket name.
#
# Bucket naming convention:  tfstate-{AccountId}
#
# Usage:  ./setup/init-terraform.sh
#
# Pre-requisite: valid AWS credentials (aws sts get-caller-identity).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOMAIN_JSON="${PROJECT_ROOT}/domain.json"

if [[ ! -f "${DOMAIN_JSON}" ]]; then
    echo "ERROR: domain.json not found at ${DOMAIN_JSON}" >&2
    exit 1
fi

REGION=$(jq -r .aws_region "$DOMAIN_JSON")

# Resolve account ID from current AWS credentials
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) || true
if [[ -z "${ACCOUNT_ID}" ]]; then
    echo "ERROR: could not resolve AWS Account ID." >&2
    echo "       Make sure you have valid AWS credentials configured." >&2
    exit 1
fi

echo "AWS Account ID: ${ACCOUNT_ID}"
echo "AWS region:     ${REGION}"
echo ""

for ENV in dev int prod; do
    BUCKET="tfstate-${ACCOUNT_ID}"
    CONF="${PROJECT_ROOT}/infrastructure/environments/${ENV}/backend.conf"
    cat > "${CONF}" <<EOF
# Auto-generated - run setup/init-terraform.sh to regenerate.
# Bucket convention: tfstate-{AccountId}
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
