#!/usr/bin/env bash
# ─── Generate Terraform backend config files from domain.json ────
# Run this after changing domain.json to regenerate backend.conf
# for all environments.
#
# Usage:
#   ./setup/init-terraform.sh                  # generate backend.conf only
#   ./setup/init-terraform.sh --create-buckets # also create S3 tfstate buckets

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOMAIN_JSON="${PROJECT_ROOT}/domain.json"
CREATE_BUCKETS=false

if [[ "${1:-}" == "--create-buckets" ]]; then
    CREATE_BUCKETS=true
fi

if [[ ! -f "${DOMAIN_JSON}" ]]; then
    echo "ERROR: domain.json not found at ${DOMAIN_JSON}" >&2
    exit 1
fi

ABBR=$(jq -r .domain_abbr "$DOMAIN_JSON")
REGION=$(jq -r .aws_region "$DOMAIN_JSON")

echo "Domain abbreviation: ${ABBR}"
echo "AWS region:          ${REGION}"
echo ""

for ENV in dev int prod; do
    BUCKET="${ABBR}-tfstate-${ENV}"
    CONF="${PROJECT_ROOT}/infrastructure/environments/${ENV}/backend.conf"
    cat > "${CONF}" <<EOF
# Auto-generated from domain.json - run setup/init-terraform.sh to regenerate.
bucket         = "${BUCKET}"
region         = "${REGION}"
use_lockfile   = true
EOF
    echo "Generated: infrastructure/environments/${ENV}/backend.conf"

    if [[ "${CREATE_BUCKETS}" == true ]]; then
        if aws s3api head-bucket --bucket "${BUCKET}" 2>/dev/null; then
            echo "  Bucket already exists: ${BUCKET}"
        else
            echo "  Creating bucket: ${BUCKET}"
            aws s3api create-bucket --bucket "${BUCKET}" \
                --region "${REGION}" \
                --create-bucket-configuration LocationConstraint="${REGION}"
            aws s3api put-bucket-versioning --bucket "${BUCKET}" \
                --versioning-configuration Status=Enabled
            aws s3api put-public-access-block --bucket "${BUCKET}" \
                --public-access-block-configuration \
                BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
            echo "  Created: ${BUCKET} (versioned, public access blocked)"
        fi
    fi
done

echo ""
if [[ "${CREATE_BUCKETS}" == true ]]; then
    echo "Backend config generated and S3 buckets ensured for all environments."
else
    echo "Run 'terraform init -backend-config=backend.conf' in each environment directory."
    echo "Tip: pass --create-buckets to also create the S3 tfstate buckets."
fi
