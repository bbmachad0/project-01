# domain-project — Enterprise AWS Data Mesh Domain Repository

Production-ready mono-repository for an AWS Data Mesh domain built on **AWS Glue 5.1 (Spark 3.5.4)**, **Apache Iceberg**, **Terraform**, and **GitHub Actions**. Designed to support **~300 Glue jobs** within a single domain, with environment-agnostic Spark code that runs identically in local development and AWS.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        domain-project                           │
├──────────────┬──────────────┬───────────────┬───────────────────┤
│  src/        │ infrastructure/ │ .github/     │ Build / Config   │
│  domain_     │ modules/       │ workflows/   │ pyproject.toml   │
│  project/    │ central/       │   ci.yml     │ Makefile         │
│  ├─ core/    │ jobs/          │   deploy-*   │ Dockerfile       │
│  └─ jobs/    │ environments/  │              │                  │
│    ├─ sales/ │   dev/int/prod │              │                  │
│    ├─ customers/│             │              │                  │
│    └─ legacy/│               │              │                  │
└──────────────┴──────────────┴───────────────┴───────────────────┘
```

### Key Principles

| Principle | Implementation |
|-----------|---------------|
| **Environment-agnostic Spark** | `get_spark()` factory detects `ENV` and returns a local or Glue-managed session |
| **No Glue imports in business logic** | All `awsglue` interaction is isolated; jobs use pure PySpark DataFrame API |
| **Shared code as .whl** | `core/` is packaged as a wheel and uploaded to S3 for Glue `--extra-py-files` |
| **Jobs as standalone scripts** | Each job is a self-contained Python script — not packaged in the wheel |
| **IaC with Terraform** | Modular Terraform with separate layers for central infra and per-job resources |
| **Multi-account deployment** | dev → int → prod with separate AWS accounts, OIDC auth, and GitHub environments |

---

## Repository Structure

```
domain-project/
│
├── src/domain_project/
│   ├── core/                    # Shared library (packaged as .whl)
│   │   ├── spark_session.py     # get_spark() factory
│   │   ├── logging.py           # Structured logging
│   │   ├── readers.py           # Generic DataFrame readers
│   │   ├── writers.py           # Generic DataFrame writers + Iceberg MERGE
│   │   ├── config.py            # Environment-agnostic config resolver
│   │   └── iceberg.py           # Iceberg DDL & maintenance utilities
│   │
│   └── jobs/                    # Glue job scripts (NOT in the wheel)
│       ├── sales/
│       │   └── job_daily_sales.py
│       ├── customers/
│       │   └── job_customer_delta.py
│       └── legacy_refactor/
│           └── job_step01.py
│
├── tests/                       # Unit tests (pytest)
│
├── infrastructure/
│   ├── modules/                 # Reusable Terraform modules
│   │   ├── glue_job/
│   │   ├── stepfunction_pipeline/
│   │   ├── iam_role/
│   │   └── s3_bucket/
│   ├── central/                 # Shared infra (S3, VPC, IAM)
│   ├── jobs/                    # Per-job Terraform definitions
│   └── environments/            # Per-env root modules
│       ├── dev/
│       ├── int/
│       └── prod/
│
├── .github/workflows/           # CI/CD pipelines
│   ├── ci.yml
│   ├── deploy-dev.yml
│   ├── deploy-int.yml
│   └── deploy-prod.yml
│
├── Dockerfile                   # Local Spark dev environment
├── pyproject.toml               # Build config — only core/ in the wheel
├── Makefile                     # Developer commands
└── README.md
```

---

## Getting Started

### Prerequisites

- Python 3.11+
- Java 17 (for local PySpark)
- Docker (optional, for containerised local runs)
- Terraform >= 1.14
- AWS CLI v2

### Bootstrap

The fastest way to get a working local environment:

```bash
# Full automated setup — creates venv, installs deps, verifies core imports
make bootstrap

# Or run the script directly
./scripts/bootstrap.sh

# Docker-based setup (no local Python/Java required)
make bootstrap-docker
```

The bootstrap script is **idempotent** — safe to run repeatedly. It will:

1. Validate system dependencies (Python 3.11+, Java 17+)
2. Create a `.venv` virtual environment (if absent)
3. Install the project in editable mode with dev extras
4. Copy `.env.example` → `.env` (if `.env` doesn't exist)
5. Verify that the core library imports correctly
6. Run a quick lint check

With `--docker` it builds the Spark development image instead of a local venv.

### Manual Setup

```bash
# Install in editable mode with dev dependencies
make install

# Run unit tests
make test

# Run a job locally
make run-local JOB=sales/job_daily_sales.py

# Or use Docker
make docker-build
make docker-run JOB=sales/job_daily_sales.py
```

### Building the Wheel

```bash
make build
# Output: dist/domain_project-1.0.0-py3-none-any.whl
```

Only `domain_project.core` is included in the wheel. Job scripts are synced to S3 separately.

---

## Spark Session

Every job obtains its session through a single call:

```python
from domain_project.core.spark_session import get_spark
spark = get_spark()
```

| `ENV` value | Behaviour |
|-------------|-----------|
| `local` (default) | Creates a local SparkSession with Iceberg extensions and Glue Catalog configured via Maven packages |
| `dev` / `int` / `prod` | Returns the pre-configured session provided by the AWS Glue 5.1 runtime |

No environment-specific logic exists inside any job file.

---

## Configuration

The `get_config()` function resolves values from (in order of precedence):

1. Explicit keyword arguments
2. `DOMAIN_PROJECT_<KEY>` environment variables
3. JSON/YAML config file (`CONFIG_PATH`)
4. Hard-coded defaults

```python
from domain_project.core.config import get_config
cfg = get_config()
bucket = cfg["s3_raw_bucket"]   # → "domain-project-raw"
```

---

## Terraform

### Module Hierarchy

```
environments/<env>/main.tf
  └── central/        (S3 buckets, VPC, subnets, IAM)
  └── jobs/           (Glue jobs + StepFunctions pipelines)
        └── modules/glue_job
        └── modules/stepfunction_pipeline
        └── modules/iam_role
        └── modules/s3_bucket
```

### Adding a New Glue Job

1. Create a new job script under `src/domain_project/jobs/<domain>/`
2. Add a `module "job_xxx"` block in `infrastructure/jobs/<domain>_jobs.tf` using the `glue_job` module
3. Optionally add it to a StepFunction pipeline
4. The CI/CD pipeline handles uploading the script and applying Terraform

### Running Terraform Locally

```bash
make terraform-plan-dev
make terraform-plan-int
make terraform-plan-prod
```

---

## CI/CD

### Branch Strategy

```
feature/*  ──PR──▶  dev  ──PR──▶  int  ──PR──▶  main (prod)
                     │              │               │
                  Deploy Dev    Deploy Int     Deploy Prod
```

### Pipeline Steps

| Stage | Actions |
|-------|---------|
| **CI** (all branches) | Install deps → Lint → Unit tests → Terraform validate → Build wheel |
| **Deploy-Dev** | Upload scripts to S3 → Upload wheel → `terraform apply` (dev account) |
| **Deploy-Int** | Same, targeting INT AWS account |
| **Deploy-Prod** | Same, targeting PROD AWS account (with manual approval) |

### AWS Authentication

All workflows use **GitHub OIDC** — no static credentials. Configure these secrets per GitHub environment:

| Environment | Secret |
|-------------|--------|
| `dev` | `AWS_ROLE_ARN_DEV` |
| `int` | `AWS_ROLE_ARN_INT` |
| `prod` | `AWS_ROLE_ARN_PROD` |

---

## Adding a New Job (Checklist)

1. **Create the script** — `src/domain_project/jobs/<domain>/job_<name>.py`
2. **Import core** — `from domain_project.core.spark_session import get_spark`
3. **Write transform functions** — pure PySpark, no Glue imports
4. **Add unit tests** — `tests/test_<name>.py`
5. **Add Terraform** — new `module "job_<name>"` in `infrastructure/jobs/<domain>_jobs.tf`
6. **Open PR** — CI validates everything, deploy on merge

---

## Scaling to ~300 Jobs

The structure is designed for scale:

- **Job scripts** live under domain-specific subdirectories (`sales/`, `customers/`, `legacy_refactor/`, …)
- **Terraform job definitions** are split per domain (`sales_jobs.tf`, `customer_jobs.tf`, …)
- **Shared logic** lives in `core/` — one wheel, referenced by every job via `--extra-py-files`
- **Pipelines** compose jobs through StepFunctions, keeping orchestration out of the code
- **No monolithic Terraform files** — each domain team manages its own `*_jobs.tf`

---

## License

Proprietary. See [LICENSE](LICENSE) for details.