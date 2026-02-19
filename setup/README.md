# Setup Guide

Plug-and-play setup for Ubuntu 24.04+ / WSL2. The bootstrap script
installs **all** required tools and configures the development environment.

---

## Quick Start

```bash
./setup/bootstrap.sh
```

That is it. The script is **idempotent** - safe to run repeatedly.

---

## What gets installed

| Tool | Version | Purpose |
|------|---------|---------|
| **Java** | OpenJDK 17 | Spark runtime |
| **Python** | 3.11 (deadsnakes PPA) | Glue 5.1 target runtime |
| **Scala** | 2.12.18 | Spark runtime, JAR building |
| **Spark** | 3.5.6 | Local spark-submit / spark-shell |
| **AWS CLI** | v2 | Cloud operations, S3 uploads |
| **Terraform** | Latest (HashiCorp APT) | Infrastructure provisioning |
| **UV** | Latest (with UVX) | Fast Python package management |
| **jq** | System package | JSON parsing in scripts |
| **boto3** | pip dependency | AWS SDK for Python |

All versions are defined as constants at the top of `bootstrap.sh`.

---

## What gets configured

1. **System tools** - installed via `apt`, official installers, or language-specific channels.
2. **Environment variables** - `JAVA_HOME`, `SPARK_HOME`, `SCALA_HOME`, `PYSPARK_PYTHON` written to `/etc/profile.d/data-domain-tools.sh`.
3. **Virtual environment** - `.venv` created via UV with Python 3.11.
4. **Project dependencies** - `pip install -e ".[dev]"` (includes PySpark, boto3, pytest, ruff, mypy, build).
5. **`.env` file** - generated from `domain.json` with local defaults (skipped if already exists).
6. **Verification** - core library imports are tested, linter runs a quick check.

---

## Pre-requisites

- Ubuntu 24.04+ or WSL2 running Ubuntu 24.04+
- `sudo` access for system package installation
- **Terraform state S3 buckets** must exist before the first deploy

### Terraform state buckets

Terraform stores its state in S3. These buckets are **not** created by
Terraform itself (chicken-and-egg problem) and must be provisioned
manually **once per environment** before the first `terraform init`.

The bucket name follows the pattern:

```
{tfstate_bucket}-{env}
```

For example, with `"tfstate_bucket": "f01-tfstate"` in `domain.json`:

| Environment | Bucket name |
|-------------|-------------|
| dev | `f01-tfstate-dev` |
| int | `f01-tfstate-int` |
| prod | `f01-tfstate-prod` |

Create them via the AWS Console or CLI:

```bash
for ENV in dev int prod; do
  aws s3api create-bucket \
    --bucket f01-tfstate-${ENV} \
    --region eu-west-1 \
    --create-bucket-configuration LocationConstraint=eu-west-1

  aws s3api put-bucket-versioning \
    --bucket f01-tfstate-${ENV} \
    --versioning-configuration Status=Enabled

  aws s3api put-public-access-block \
    --bucket f01-tfstate-${ENV} \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
done
```

> **Recommended**: enable versioning and block public access (shown above).

---

## `domain.json`

All domain-specific names derive from a single file at the repository root:

```json
{
  "domain_name": "finance01",
  "domain_abbr": "f01",
  "aws_region": "eu-west-1",
  "tfstate_bucket": "f01-tfstate"
}
```

| Field | Description | Example |
|-------|-------------|---------|
| `domain_name` | Full domain name | `finance01` |
| `domain_abbr` | Short abbreviation used in resource names | `f01` |
| `aws_region` | AWS region for all resources | `eu-west-1` |
| `tfstate_bucket` | **Prefix** of the S3 bucket for Terraform state. The environment suffix (`-dev`, `-int`, `-prod`) is appended automatically. | `f01-tfstate` |

Edit this file **before** running the bootstrap if you are adapting the
repository for a different domain.

---

## Docker alternative

If you prefer a container-based approach:

```bash
./setup/bootstrap.sh --docker
```

This builds a local Docker image with all dependencies baked in.

---

## Terraform backends

After bootstrap, generate the Terraform backend configurations:

```bash
./setup/init-terraform.sh
```

This reads `domain.json` and creates `backend.conf` files inside each
environment root (`infrastructure/environments/{dev,int,prod}/`).

Then initialise Terraform:

```bash
make terraform-init-dev
make terraform-init-int
make terraform-init-prod
```

---

## GitHub Secrets (CI/CD)

The pipelines authenticate to AWS via **OIDC** - no static credentials.
Create the following secrets in your GitHub repository:

| GitHub Environment | Secret | Value |
|--------------------|--------|-------|
| `dev` | `AWS_ROLE_ARN_DEV` | ARN of the OIDC role for the **dev** account |
| `int` | `AWS_ROLE_ARN_INT` | ARN of the OIDC role for the **int** account |
| `prod` | `AWS_ROLE_ARN_PROD` | ARN of the OIDC role for the **prod** account |

See [docs/ci-cd.md](../docs/ci-cd.md) for the full OIDC trust policy.

---

## Verify

```bash
source .venv/bin/activate

make test          # Unit tests
make lint          # Linters (ruff, mypy)
make build         # Build the core wheel
```

You are ready to develop. See [docs/](../docs/) for detailed documentation.
