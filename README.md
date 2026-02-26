# AWS Data Mesh Domain

> Production-ready mono-repository template for a single **AWS Data Mesh domain**- batteries included with AWS Glue 5.1, Apache Iceberg, Terraform IaC, GitHub Actions CI/CD, and a security-first design aligned with the AWS Well-Architected Framework.

[![License](https://img.shields.io/badge/license-Proprietary-red.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.11-blue.svg)](https://www.python.org/)
[![Spark](https://img.shields.io/badge/spark-3.5-orange.svg)](https://spark.apache.org/)
[![Terraform](https://img.shields.io/badge/terraform-%3E%3D1.14-7B42BC.svg)](https://www.terraform.io/)

---

## Table of Contents

1. [What is a Data Mesh?](#1-what-is-a-data-mesh)
2. [This Repository's Role](#2-this-repositorys-role)
3. [Core Design Principles](#3-core-design-principles)
4. [Technology Stack](#4-technology-stack)
5. [Repository Structure](#5-repository-structure)
6. [Architecture Deep Dive](#6-architecture-deep-dive)
7. [Getting Started](#7-getting-started)
8. [Local Development](#8-local-development)
9. [Environments & AWS Accounts](#9-environments--aws-accounts)
10. [Infrastructure Management](#10-infrastructure-management)
11. [CI/CD Pipeline](#11-cicd-pipeline)
12. [Security Model](#12-security-model)
13. [Documentation Index](#13-documentation-index)
14. [Contributing](#14-contributing)
15. [Backlog & Improvement Tasks](#15-backlog--improvement-tasks)

---

## 1. What is a Data Mesh?

A **Data Mesh** is a data architecture paradigm that decentralises data ownership from a central data team to individual **domain teams**- the people who best understand the data they produce. Instead of a single data lake or data warehouse owned by one platform team, a Data Mesh is composed of many **domain units**, each responsible for:

- Producing and maintaining their own data as a **product**.
- Publishing data with well-defined **contracts** (schemas, SLAs).
- Providing infrastructure and pipelines for their own data flows.
- Enabling other domains to **discover and consume** their outputs via self-service.

This architecture addresses the scalability and ownership bottlenecks that arise when a central team is responsible for all data, while still providing governance guardrails through shared platform infrastructure.

### The Four Pillars of Data Mesh

| Pillar | What it means here |
|---|---|
| **Domain Ownership** | Each domain (this repo) fully owns its data, pipelines, infrastructure, and CI/CD. |
| **Data as a Product** | Outputs (curated Iceberg tables) are treated as products with schemas, SLAs, and documentation. |
| **Self-Serve Platform** | Shared `dp_foundation` library (from [`org-data-platform-foundation`](https://github.com/ORG/org-data-platform-foundation)), `_template/` project scaffold, and `bootstrap.sh` enable any team to bootstrap a new domain quickly. |
| **Federated Governance** | KMS CMK, IAM isolation, tagging, and automated security scanning enforce organisational standards without a central gatekeeper. |

---

## 2. This Repository's Role

This repository is **one domain unit** inside an AWS Data Mesh. It is designed as a **plug-and-play template**: clone it, edit `setup/domain.json`, and you have a fully wired domain with:

- Three-layer data lake (raw → refined → curated) on S3 with encryption, versioning, and access logging.
- AWS Glue 5.1 (Apache Spark 3.5) for distributed processing.
- Apache Iceberg format for curated and refined tables with automatic compaction and snapshot management.
- AWS Step Functions for job orchestration.
- Shared Python library ([`dp_foundation`](https://github.com/ORG/org-data-platform-foundation)) for consistent config, logging, and I/O across all jobs.
- Per-project IAM isolation- each project runs with its own scoped role.
- GitHub Actions CI/CD with OIDC authentication (no stored credentials).
- Multiple environments (dev / int / prod) as independent AWS account deployments.

Within this domain, you create **projects**- isolated units of work (e.g. `sales`, `customers`, `inventory`)- each with their own tables, Glue jobs, optimizers, and pipelines. Adding a new project requires copying a template directory and filling in a few files; **no central files need to be modified**.

---

## 3. Core Design Principles

### Plug-and-Play

New projects are bootstrapped by copying `infrastructure/projects/_template/` and editing `project.json`. CI/CD auto-discovers new projects via `find infrastructure/projects -name 'project.json'`. Nothing in any central pipeline file needs to change.

### DRY (Don't Repeat Yourself)

- All resource naming derives from `setup/domain.json`- change it once, every bucket, database, job name, and IAM role updates automatically.
- The `dp_foundation` library (maintained in [`org-data-platform-foundation`](https://github.com/ORG/org-data-platform-foundation)) eliminates boilerplate from every Glue job (Spark session creation, config resolution, structured logging, Iceberg I/O).
- Reusable Terraform modules (`glue_job`, `glue_iceberg_table`, `s3_bucket`, etc.) encode best-practice patterns once and are instantiated per project.
- Environment root modules (`dev/`, `int/`, `prod/`) are structurally identical- differences (VPC CIDR, account) are the only thing that varies.

### Environment Agnostic

Jobs contain **no environment-specific logic**. `get_spark()` detects whether it is running locally or on AWS Glue, and `get_config()` resolves bucket names, database names, and settings from environment variables with graceful fallback to `domain.json`-derived defaults. The same `.py` file runs identically on a developer's laptop and in AWS Glue.

### Security by Default

Every resource provisioned follows the principle of least privilege. S3 buckets enforce encryption (CMK), block public access, deny HTTP transport, and log all access. IAM roles are per-project and scoped to their S3 prefix. CI/CD uses OIDC- no static credentials are stored anywhere. KMS has an explicit key policy. VPC Flow Logs capture all traffic.

### Full Auditability

All Terraform-managed AWS resources carry `git_sha`, `deployed_by`, and `repository` tags automatically injected from the GitHub Actions context. Every wheel deploy is versioned with the commit SHA. AWS resource changes are audited via the organisational CloudTrail account.

---

## 4. Technology Stack

| Technology | Version / Details | Role |
|---|---|---|
| **Python** | 3.11 | Glue job runtime, tests |
| **Apache Spark** | 3.5.6 (via AWS Glue 5.1) | Distributed processing engine |
| **Apache Iceberg** | 1.7.1 | Open table format (refined/curated layers) |
| **Terraform** | ≥ 1.14 | Infrastructure as Code |
| **AWS Provider** | ~> 5.0 | Terraform AWS resources |
| **AWS Glue** | 5.1 | Managed Spark runtime |
| **AWS Step Functions** |- | Job orchestration |
| **AWS S3** |- | Data lake storage (3 layers + artifacts + logs) |
| **AWS KMS** | CMK | Encryption for S3, CloudWatch Logs |
| **AWS VPC** |- | Network isolation for Glue jobs |
| **GitHub Actions** |- | CI/CD |
| **GitHub OIDC** |- | Keyless AWS authentication from CI |
| **Docker** | python:3.11-slim + Spark 3.5 | Local development environment |
| **UV** | Latest | Fast Python package manager |
| **Ruff** | ≥ 0.4 | Linting and formatting |
| **Mypy** | ≥ 1.8 | Static type checking |
| **Pytest** | ≥ 7.0 | Unit testing |
| **pip-audit** | Latest | Python SCA (CVE scanning) |
| **Bandit** | Latest | Python SAST |
| **Checkov** | Latest | IaC / Dockerfile SAST |

---

## 5. Repository Structure

```
.
├── setup/
│   ├── domain.json              # Single source of truth: domain name, abbr, region
│   ├── bootstrap.sh             # One-time local setup: Java, Python, Spark, Terraform, AWS CLI
│   ├── init-terraform.sh        # Generates backend.conf for each environment from domain.json
│   └── README.md                # Detailed setup guide
│
├── src/
│   └── jobs/
│       ├── project01/           # Standalone .py scripts for project01 (NOT packaged in wheel)
│       └── test02/              # Standalone .py scripts for test02
│
├── tests/
│   ├── conftest.py              # Shared fixtures (local SparkSession, test config)
│   ├── test_config.py           # Tests for dp_foundation.config
│   ├── test_logging.py          # Tests for dp_foundation.logging
│   └── test_jobs.py             # Integration-style tests for job logic
│
├── infrastructure/
│   ├── modules/                 # Reusable Terraform primitives
│   │   ├── glue_job/            # AWS Glue Job + default arguments
│   │   ├── glue_catalog_database/  # Glue Database resource
│   │   ├── glue_catalog_table/     # Standard (Hive/Parquet) table
│   │   ├── glue_iceberg_table/     # Iceberg table + 3 automatic optimizers
│   │   ├── iam_glue_job/           # Per-project Glue execution role (S3+Catalog scoped)
│   │   ├── iam_table_optimizer/    # Per-project Table Optimizer role
│   │   ├── iam_role/               # Generic IAM role (used for SFN)
│   │   ├── s3_bucket/              # S3 with encryption, versioning, lifecycle, logging
│   │   └── stepfunction_pipeline/  # Step Functions ASL + CloudWatch log group (KMS)
│   │
│   ├── baseline/              # Domain-wide shared infrastructure (applied once per env)
│   │   ├── s3.tf                # 5 S3 buckets: raw, refined, curated, artifacts, logs
│   │   ├── kms.tf               # CMK with explicit key policy + CloudWatch Logs grant
│   │   ├── glue_databases.tf    # Glue databases for each layer
│   │   ├── iam_orchestration.tf # Step Functions execution role
│   │   ├── vpc.tf               # VPC + private subnets + VPC Flow Logs (KMS encrypted)
│   │   ├── subnets.tf           # Subnets, VPC endpoints (S3 + Glue), security groups
│   │   ├── variables.tf         # domain_abbr, env, aws_region, vpc_cidr
│   │   └── outputs.tf           # All resource ARNs/IDs re-exported for projects
│   │
│   ├── projects/
│   │   ├── _template/           # ⭐ Copy this to create a new project
│   │   │   ├── project.json     # { "name": "REPLACE_ME" }
│   │   │   ├── providers.tf     # AWS provider with traceability default_tags
│   │   │   ├── variables.tf     # environment variable + traceability vars
│   │   │   ├── locals.tf        # Wires domain.json, project.json, baseline outputs
│   │   │   ├── data.tf          # data.terraform_remote_state.baseline
│   │   │   ├── tables.tf        # Table definitions
│   │   │   ├── jobs.tf          # Glue Job modules
│   │   │   ├── iam.tf           # Instantiates iam_glue_job + iam_table_optimizer
│   │   │   ├── optimizers.tf    # Table optimizer resources
│   │   │   ├── pipelines.tf     # Step Functions pipelines
│   │   │   └── outputs.tf       # Exports for cross-project use
│   │   ├── project01/           # Example project
│   │   └── test02/              # Example project
│   │
│   └── environments/            # Root Terraform modules (one per environment/account)
│       ├── dev/
│       │   ├── main.tf          # Instantiates foundation module + traceability vars
│       │   ├── outputs.tf       # Re-exports ALL baseline outputs for projects
│       │   └── backend.conf     # Generated by init-terraform.sh (git-ignored)
│       ├── int/
│       └── prod/
│
├── .github/
│   └── workflows/
│       ├── ci.yml               # Lint → test → Terraform validate → security scan
│       ├── _deploy.yml          # Reusable deploy logic (called by deploy-*.yml)
│       ├── deploy-dev.yml       # Trigger: push to dev
│       ├── deploy-int.yml       # Trigger: push to int
│       ├── deploy-prod.yml      # Trigger: push to main
│       └── terraform-plan-pr.yml  # Posts full plan output as PR comment
│
├── docs/
│   ├── architecture.md          # Domain hierarchy, data layers, naming conventions
│   ├── creating-a-project.md    # Step-by-step project creation guide
│   ├── adding-a-job.md          # Adding a Glue job to an existing project
│   ├── ci-cd.md                 # CI/CD branch strategy, OIDC setup, IAM trust policy
│   ├── terraform.md             # Module hierarchy, backend, remote state patterns
│   └── tasks.md                 # Engineering backlog (SecOps, DevOps, Platform)
│
├── Dockerfile                   # Local Spark dev image (mirrors Glue 5.1)
├── Makefile                     # Developer task runner (run `make help`)
└── pyproject.toml               # Python project metadata, tool config (ruff, mypy, pytest)
```

---

## 6. Architecture Deep Dive

### 6.1 Data Layers (S3)

Data flows through three immutable layers, each with a dedicated S3 bucket and Glue database:

```
Source Systems
      │
      ▼
 ┌─────────┐   Standard (Hive/Parquet)
 │   RAW   │   Landing zone. Data arrives here as-is from source systems.
 └────┬────┘   No transformations. Useful for replay and debugging.
      │
      ▼
 ┌──────────┐  Apache Iceberg
 │ REFINED  │  Cleaned, typed, conformed. Tables are joinable and reusable
 └────┬─────┘  across projects within the domain.
      │
      ▼
 ┌──────────┐  Apache Iceberg
 │ CURATED  │  Business-ready, aggregated, denormalised. These are the
 └──────────┘  "data products" consumed by other domains or BI tools.
```

Two additional buckets support the platform:

- **artifacts**- stores the versioned `dp_foundation` Python wheel (`.whl`) from [`org-data-platform-foundation`](https://github.com/ORG/org-data-platform-foundation) and all Glue job scripts (`.py`).
- **logs**- receives S3 server access logs from all other buckets.

**Bucket naming:** `{domain_abbr}-{purpose}-{account_id}-{country_code}-{env}`, e.g. `f01-raw-390403879405-de-dev`. The account ID is resolved dynamically from STS- never hardcoded.

**All data buckets are configured with:**
- KMS CMK encryption (`bucket_key_enabled = true` for cost efficiency)
- Versioning enabled
- Non-current version expiry after 90 days
- Incomplete multipart upload abort after 7 days
- Block all public access
- `DenyInsecureTransport` S3 bucket policy (enforces HTTPS-only)
- Server access logging to the `logs` bucket
- `prevent_destroy = true` lifecycle rule

### 6.2 Domain & Project Hierarchy

```
Domain  (this repository)
  └── Project  (e.g. sales, customers, inventory)
        ├── Tables         RAW → Standard (Hive/Parquet); REFINED/CURATED → Iceberg
        ├── Glue Jobs      PySpark ETL scripts that import from the dp_foundation library
        ├── Optimizers     Iceberg compaction, orphan cleanup, snapshot retention
        └── Pipelines      AWS Step Functions orchestrating job sequences
```

A **domain** owns the shared infrastructure (buckets, VPC, KMS, Glue databases, IAM orchestration). **Projects** are isolated workloads- each has its own IAM role, S3 prefix, and Terraform remote state. Multiple developers can work on different projects simultaneously without conflicting.

### 6.3 Single Source of Truth- `domain.json`

All resource naming, CI/CD configuration, and Python runtime config derive from one file:

```json
{
  "domain_name": "finance01",
  "domain_abbr": "f01",
  "aws_region": "eu-west-1"
}
```

| Field | Where it is used |
|---|---|
| `domain_name` | Terraform descriptions, AWS resource tags |
| `domain_abbr` | All resource name prefixes (`f01-raw-...`, `f01_de_raw` database, etc.) |
| `aws_region` | AWS provider region, bucket region, `.env` generation |

**Edit this file once** when cloning the template for a new domain. Every other file reads from it automatically.

### 6.4 Naming Conventions

| Resource | Pattern | Example |
|---|---|---|
| S3 bucket | `{abbr}-{purpose}-{account_id}-{country_code}-{env}` | `f01-raw-390403879405-de-dev` |
| Glue database | `{abbr}_{country_code}_{layer}` | `f01_de_raw` |
| Glue job | `{abbr}-{project_name}-{job_name}-{env}` | `f01-sales-daily-load-dev` |
| Step Functions | `{abbr}-{project_name}-pipeline-{name}-{env}` | `f01-sales-pipeline-ingest-dev` |
| IAM role (Glue) | `{abbr}-glue-{project_name}-{env}` | `f01-glue-sales-dev` |
| IAM role (Optimizer) | `{abbr}-optimizer-{project_name}-{env}` | `f01-optimizer-sales-dev` |
| S3 data prefix | `{bucket}/{project_name}/...` | `f01-raw-.../sales/` |
| KMS alias | `alias/{abbr}-data-lake-{env}` | `alias/f01-data-lake-dev` |

The `{project_name}` (project name) is declared once in `project.json` and substituted everywhere via `locals.tf`.

### 6.5 Shared Python Library- `dp_foundation`

The `dp_foundation` package is maintained in the standalone repository [`org-data-platform-foundation`](https://github.com/ORG/org-data-platform-foundation). It is built as a Python wheel, published as a GitHub Release asset, downloaded by this domain's CI/CD, uploaded to S3, and referenced via `--extra-py-files` on every Glue job. Jobs **never** import `awsglue` directly.

```
dp_baseline/
├── spark/session.py     → get_spark(app_name) - local vs Glue session factory
├── config/settings.py   → get_config()        - env-var-aware runtime config resolution
├── io/readers.py        → read_iceberg(), read_table()
├── io/writers.py        → write_iceberg(), merge_iceberg()
├── iceberg/catalog.py   → DDL helpers (create table, alter schema)
├── logging/logger.py    → get_logger(name)    - JSON or text structured logging
└── quality/checks.py    → Data quality assertion utilities
```

#### Config Resolution Order (highest → lowest precedence)

1. Explicit keyword arguments passed to `get_config(overrides=...)`
2. Environment variables: `{ABBR}_<KEY>`- e.g. `F01_S3_RAW_BUCKET`
3. A YAML/JSON file pointed to by `CONFIG_PATH`
4. Defaults derived from `domain.json` + AWS account ID (resolved via STS)

This means jobs run identically with `ENV=local` (developer laptop) and `ENV=dev`/`int`/`prod` (Glue), resolving the correct bucket names automatically in both contexts.

#### Spark Session Factory

`get_spark()` inspects the `ENV` variable:

- `ENV=local`: builds a **standalone PySpark** session with Iceberg extensions and the AWS Glue Catalog, downloading required JARs via Maven automatically.
- Any other value: returns the **managed Glue session** (already configured by the Glue runtime- no extra config needed).

This is how the same job script runs on a developer's laptop **and** in AWS Glue without any conditional branching in job code.

### 6.6 Glue Job Execution Model

Each Glue job is provisioned by the `modules/glue_job` Terraform module. Key attributes:

- **Glue 5.1** runtime (Python 3.11, Spark 3.5.6).
- The versioned `dp_foundation` wheel is passed via `--extra-py-files`.
- Job scripts live in S3 at `{artifacts_bucket}/{project_name}/jobs/{job_name}.py` and are **not** baked into the wheel- updating a script does not require a wheel rebuild.
- All jobs run inside the domain **VPC** via a shared Glue Network Connection- traffic to S3 and the Glue Catalog never leaves the AWS network.
- Temporary files (Spark shuffle, Glue bookmarks) go to `{artifacts_bucket}/glue-temp/{project_name}/`.

### 6.7 Iceberg Table Lifecycle

The `modules/glue_iceberg_table` module creates an Iceberg table **and** its three mandatory optimizers in one call:

| Optimizer | What it does | Default schedule |
|---|---|---|
| **Compaction** | Merges small files into larger ones for better read performance | Every 6 hours |
| **Snapshot retention** | Expires old snapshots, keeping the last N days (default 7) and at least 3 | Daily |
| **Orphan file cleanup** | Deletes files not referenced by any snapshot (may result from failed writes) | Weekly |

Optimizers are provisioned **automatically** alongside the table- no manual configuration needed.

### 6.8 Terraform Layer Model

```
environments/<env>/main.tf                   ← Root module (entry point per environment)
  └── module "baseline"                    ← baseline/ (shared domain infra)
         ├── KMS, S3, VPC, IAM, Glue DBs
         └── outputs.tf  ─────────────────── stored in S3 remote state
                                                ↑
projects/<name>/                             ← Independent root module per project
  └── data.terraform_remote_state.baseline ← reads baseline outputs from S3
  └── locals.tf                              ← wires domain.json + project.json + baseline
         ├── tables.tf, jobs.tf, iam.tf
         └── pipelines.tf, optimizers.tf
```

Projects are **independent Terraform root modules**- each has its own S3 remote state (`projects/{project_name}/terraform.tfstate`) and is applied independently. This enables parallel deployments in CI and prevents a broken project from blocking others.

Projects read baseline outputs via `data.terraform_remote_state`- they never hardcode bucket names or ARNs.

### 6.9 Per-Project IAM Isolation

Each project provisioned by `iam.tf` gets two dedicated IAM roles:

**Glue Execution Role** (`modules/iam_glue_job`):

| Permission | Scope |
|---|---|
| S3 object r/w/delete | Only `{bucket}/{project_name}/*` on data buckets |
| S3 list | Only with `s3:prefix` condition matching `{project_name}/` |
| S3 artifacts | Full read; temp write only to `glue-temp/` prefix |
| Glue Catalog read | Domain databases (`{abbr}_{country_code}_*`) + `default` |
| Glue Catalog write | Domain databases only |
| SSM Parameter Store | `/{project_name}/*` only |
| EC2 networking | `CreateNetworkInterface` scoped to domain subnet ARNs |
| CloudWatch Logs | `/aws-glue/*` log groups |
| KMS | Domain CMK only |

**Table Optimizer Role** (`modules/iam_table_optimizer`): identical S3 scope but with read/write/delete only- no EC2 networking, no SSM access.

This isolation means a compromised Glue job in `project01` **cannot** read data belonging to `project02`.

### 6.10 Networking (VPC)

All Glue jobs run inside a **dedicated VPC** with:

- 3 private subnets across availability zones (CIDRs auto-derived from `vpc_cidr`).
- No internet gateway- all outbound traffic uses VPC endpoints.
- **S3 Gateway endpoint**- free; S3 traffic never leaves AWS.
- **Glue API Interface endpoint**- Glue workers call the Glue control plane privately.
- **VPC Flow Logs**- all traffic captured to CloudWatch Logs, KMS-encrypted, 90-day retention.
- A shared **Glue Network Connection** referenced by all jobs in the domain.

### 6.11 Encryption (KMS)

A single **Customer-Managed Key (CMK)** encrypts all domain data at rest:

- All 5 S3 buckets (`bucket_key_enabled = true` for per-request cost efficiency).
- VPC Flow Log CloudWatch log group.
- Step Functions CloudWatch log groups.

The KMS key policy explicitly:

1. **Root account full control**- required; prevents permanent key lockout.
2. **Domain roles key usage**- grants all roles matching `{abbr}-*` usage permissions via `aws:PrincipalArn` condition.
3. **CloudWatch Logs service principal**- required for encrypted log groups; IAM policies alone are insufficient; uses `kms:EncryptionContext:aws:logs:arn` condition to scope the grant.

---

## 7. Getting Started

### Prerequisites

- Ubuntu 24.04+ or WSL2 (or Docker)
- `sudo` access
- AWS CLI configured with credentials for the target dev account
- A GitHub repository with OIDC configured (see [Section 11.3](#113-aws-authentication-oidc))
- Terraform state S3 buckets pre-created in each target account (see [Section 10.1](#101-bootstrap-terraform-state))

### Quick Start

**Step 1- Configure the domain**

Edit `setup/domain.json`:

```json
{
  "domain_name": "your_domain",
  "domain_abbr": "yd",
  "aws_region": "eu-west-1"
}
```

This is the **only file that must be edited** when adapting the template to a new domain.

**Step 2- Bootstrap the local environment**

```bash
./setup/bootstrap.sh
```

Installs Java 17, Python 3.11, Spark 3.5.6, Terraform, AWS CLI v2, UV, and jq. Creates `.venv/` and generates `.env`. Idempotent- safe to run again.

**Step 3- Initialise Terraform**

```bash
./setup/init-terraform.sh    # generates backend.conf for dev/int/prod
source .venv/bin/activate
make terraform-init-dev      # initialise the dev workspace
```

**Step 4- Verify the setup**

```bash
make test          # unit tests (local PySpark session)
make lint          # ruff + format check
```

---

## 8. Local Development

### 8.1 Running Jobs Locally

**Native (via Python venv)**

```bash
source .venv/bin/activate
make run-local JOB=project01/job_teste.py
```

Sets `ENV=local`, causing `get_spark()` to create a local PySpark session and `get_config()` to resolve local defaults.

**Docker (mirrors the Glue 5.1 runtime exactly)**

```bash
make docker-build
make docker-run JOB=project01/job_teste.py
```

The Docker image (`FROM python:3.11-slim`) replicates Glue 5.1: Python 3.11, OpenJDK 17, Spark 3.5.6. Your `~/.aws` credentials directory and `src/` are mounted as volumes- no credentials are baked into the image.

### 8.2 Writing a New Job

All jobs follow a consistent pattern using only `dp_foundation` abstractions:

```python
"""project_name - short description of this job."""

from dp_foundation.spark.session import get_spark
from dp_foundation.config.settings import get_config
from dp_foundation.io.readers import read_iceberg
from dp_foundation.io.writers import write_iceberg
from dp_foundation.logging.logger import get_logger


def main() -> None:
    spark = get_spark(app_name="projectname-jobname")
    cfg   = get_config()
    log   = get_logger(__name__)

    log.info("Starting job")

    # Extract
    df = read_iceberg(spark, catalog_db=cfg["iceberg_database_refined"], table="source_table")

    # Transform
    result = df  # your PySpark logic

    # Load
    write_iceberg(
        df=result,
        path=f"s3://{cfg['s3_curated_bucket']}/iceberg/target_table",
        catalog_db=cfg["iceberg_database_curated"],
        table="target_table",
        mode="append",
    )

    log.info("Job complete")
    spark.stop()


if __name__ == "__main__":
    main()
```

**Key rules:**

- No `awsglue` imports- use `dp_foundation` only.
- No environment literals or hardcoded bucket names- `get_config()` resolves them.
- No branching on `ENV` inside job logic.
- Scripts live in `src/jobs/<project>/` and are uploaded to S3 as standalone files- they are **not** packaged in the wheel.

See [docs/adding-a-job.md](docs/adding-a-job.md) for the full guide with Terraform snippets.

### 8.3 Available Make Targets

```bash
make help                            # list all targets with descriptions

# ── Development ──────────────────────────────────
make install                         # pip install -e ".[dev]"
make run-local JOB=<project/job.py>  # run a job locally with ENV=local
make docker-build                    # build the Glue 5.1 parity Docker image
make docker-run JOB=<project/job.py> # run a job inside Docker

# ── Testing & Quality ─────────────────────────────
make test                            # pytest with coverage report
make lint                            # ruff check + format check

make format                          # ruff auto-fix formatting

# ── Foundation Wheel ──────────────────────────────
make download-foundation-wheel       # download dp_foundation wheel from GitHub Releases
make upload-foundation-wheel ENVIRONMENT=dev  # upload wheel to domain S3 artifacts

# ── Infrastructure ────────────────────────────────
make terraform-init-dev|int|prod     # terraform init for the environment
make terraform-plan-dev|int|prod     # terraform plan for the environment
make terraform-apply ENVIRONMENT=dev|int|prod
make terraform-validate              # validate all Terraform files

# ── Artifacts ─────────────────────────────────────
make upload-jobs  ENVIRONMENT=dev    # sync job scripts to S3

# ── Scaffolding ───────────────────────────────────
make new-project NAME=<name>   # copy _template/ for a new project

make clean                           # remove build artefacts
```

---

## 9. Environments & AWS Accounts

| Environment | AWS Account | Branch | Deployment trigger |
|---|---|---|---|
| `local` | None | Any | `make run-local` / `make docker-run` |
| `dev` | Dev account | `dev` | Automatic on merge to `dev` |
| `int` | Int account | `int` | Automatic on merge to `int` |
| `prod` | Prod account | `main` | Manual approval + merge to `main` |

Each environment is a **separate AWS account**- blast radius is completely contained. The `ENV` variable controls all environment-specific behaviour at runtime; jobs themselves contain no account IDs or environment labels.

---

## 10. Infrastructure Management

### 10.1 Bootstrap Terraform State

Terraform state is stored in S3. These buckets must exist **before** the first `terraform init`. Create them once per account:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="eu-west-1"

aws s3api create-bucket \
  --bucket "tfstate-${ACCOUNT_ID}" \
  --region "${REGION}" \
  --create-bucket-configuration LocationConstraint="${REGION}"

aws s3api put-bucket-versioning \
  --bucket "tfstate-${ACCOUNT_ID}" \
  --versioning-configuration Status=Enabled

aws s3api put-public-access-block \
  --bucket "tfstate-${ACCOUNT_ID}" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,\
    BlockPublicPolicy=true,RestrictPublicBuckets=true
```

Bucket name: `tfstate-{AccountId}`. S3 native locking is used (`use_lockfile = true`, requires Terraform ≥ 1.10)- no DynamoDB table is needed.

### 10.2 Initialise Terraform

```bash
./setup/init-terraform.sh          # generates backend.conf for each environment
make terraform-init-dev            # initialise the baseline workspace locally
```

Projects are initialised automatically by CI at deploy time. To initialise a project workspace locally:

```bash
cd infrastructure/projects/myproject
terraform init -backend-config=../../environments/dev/backend.conf
```

### 10.3 Adding a New Project

```bash
make new-project NAME=myproject
```

This copies `_template/` to `infrastructure/projects/myproject/` and creates `src/jobs/myproject/`. Then:

1. Edit `infrastructure/projects/myproject/tables.tf`- define your tables.
2. Edit `infrastructure/projects/myproject/jobs.tf`- define your Glue jobs.
3. Edit `infrastructure/projects/myproject/pipelines.tf`- compose jobs into a Step Functions pipeline.
4. Create job scripts in `src/jobs/myproject/job_<name>.py` following the pattern in [Section 8.2](#82-writing-a-new-job).
5. Push to `dev`- CI auto-discovers and deploys the new project. No central files need changing.

See [docs/creating-a-project.md](docs/creating-a-project.md) for the complete guide.

### 10.4 Removing a Project

To decommission a project, simply delete its directories and push:

```bash
rm -rf infrastructure/projects/myproject src/jobs/myproject
git add -A && git commit -m "chore: remove myproject" && git push origin dev
```

The CI/CD pipeline automatically detects the removal and runs `terraform destroy` for the project, tearing down all its AWS resources (Glue jobs, IAM roles, tables, optimizers, Step Functions pipelines). Job scripts are also removed from S3 via `s3 sync --delete`. No manual intervention or local credentials required.

> **Note:** data objects in S3 data buckets are not deleted (buckets have `prevent_destroy = true`). Clean up data prefixes manually if needed.

See [docs/ci-cd.md- Removing a Project](docs/ci-cd.md#removing-a-project) for full details and caveats.

### 10.5 Adding a New Glue Job

1. Create `src/jobs/<project>/job_<name>.py`.
2. Add a `module "job_<name>"` block to `infrastructure/projects/<project>/jobs.tf`.
3. Optionally add the job to a Step Functions pipeline in `pipelines.tf`.
4. Push a PR targeting `dev`.

See [docs/adding-a-job.md](docs/adding-a-job.md) for the complete guide with Terraform snippets.

---

## 11. CI/CD Pipeline

### 11.1 Branch Strategy

```
feature/*  ──PR──▶  dev  ──PR──▶  int  ──PR──▶  main (prod)
                     │              │               │
                  Deploy Dev    Deploy Int     Deploy Prod
```

All development work happens on `feature/*` branches. PRs target `dev`. Promotions to `int` and `main` are also done via PRs, enabling code review at each promotion gate.

### 11.2 Workflow Overview

| Workflow | Trigger | Actions |
|---|---|---|
| `ci.yml` | Every push, every PR | Lint → test → Terraform validate → security scan |
| `deploy-dev.yml` | Push to `dev` | Baseline → artifacts → destroy removed → deploy projects (Dev account) |
| `deploy-int.yml` | Push to `int` | Baseline → artifacts → destroy removed → deploy projects (Int account) |
| `deploy-prod.yml` | Push to `main` | Baseline → artifacts → destroy removed → deploy projects (Prod account) |
| `terraform-plan-pr.yml` | PR touching `infrastructure/` | Runs `terraform plan`, posts **full** output as PR comment |

### 11.3 AWS Authentication (OIDC)

No static AWS credentials are stored. Each deploy workflow assumes an IAM role via [GitHub OIDC](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services).

**Required GitHub Secrets (per environment):**

| Secret | Value |
|---|---|
| `AWS_ROLE_ARN_DEV` | `arn:aws:iam::<dev-account>:role/<role-name>` |
| `AWS_ROLE_ARN_INT` | `arn:aws:iam::<int-account>:role/<role-name>` |
| `AWS_ROLE_ARN_PROD` | `arn:aws:iam::<prod-account>:role/<role-name>` |

**IAM Trust Policy template:**

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": "repo:<org>/<repo>:ref:refs/heads/main"
      }
    }
  }]
}
```

For `dev` and `int`, relax the `sub` condition to `"repo:<org>/<repo>:*"` to allow any branch.

### 11.4 Deploy Sequence

The reusable `_deploy.yml` workflow enforces a strict deploy order:

```
1. Detect Changes + Discover Projects
   (paths-filter for component changes; git diff for added/removed projects)
        │
        ▼
2. Baseline Terraform Apply
   (S3 buckets, KMS, VPC, Glue databases - shared infra must exist first)
        │
        ├──────────────────────────┐
        ▼                          ▼
3a. Artifacts Upload          3b. Destroy Removed Projects
   (wheel + scripts → S3)       (terraform destroy from HEAD~1)
        │
        ▼
4. Deploy Projects  (parallel matrix, auto-discovered)
   (Glue jobs reference the wheel + scripts uploaded in step 3a)
```

This ordering guarantees that S3 buckets always exist before artifacts are uploaded, artifacts always exist before Glue jobs reference them, and removed projects are torn down in the same pipeline run.

**Selective deployment:** if only `infrastructure/projects/project01/` changed, only `project01` is re-applied. If shared components changed (python, jobs, baseline, modules), all projects are re-applied.

**Automated teardown:** when a project directory is deleted from the repo, the `destroy-projects` job restores its Terraform files from `HEAD~1` and runs `terraform destroy`, ensuring the CI/CD pipeline is the single source of truth for all cloud mutations - including resource decommissioning. See [docs/ci-cd.md](docs/ci-cd.md#removing-a-project) for details.

### 11.5 Change Detection

[`dorny/paths-filter`](https://github.com/dorny/paths-filter) detects which components changed:

| Filter | Paths | Effect |
|---|---|---|
| `python` | `src/jobs/**`, `pyproject.toml`, `tests/**` | Script upload + all projects re-deployed |
| `jobs` | `src/jobs/**` | Script upload + all projects re-deployed |
| `baseline_infra` | `infrastructure/baseline/**`, `infrastructure/environments/**`, `infrastructure/modules/**`, `setup/domain.json` | Baseline + all projects re-applied |
| `projects_infra` | `infrastructure/projects/**` | Changed projects only; **removed** projects auto-destroyed |

If only `infrastructure/projects/project01/` changed, only `project01` is re-applied - other projects are bypassed. If a project directory is deleted, its AWS resources are automatically destroyed (see [Section 11.4](#114-deploy-sequence)).

### 11.6 Security Scanning in CI

The `security-scan` job in `ci.yml` runs on every push touching Python or infrastructure files:

| Tool | What it checks | Mode |
|---|---|---|
| **pip-audit** | CVEs in Python runtime dependencies | Hard-fail |
| **bandit** | Python SAST (injections, hardcoded secrets, insecure calls) | `--exit-zero` (report only) |
| **checkov** | Terraform IaC misconfigurations | `--soft-fail` (report only) |
| **checkov** | Dockerfile security best practices | `--soft-fail` (report only) |

Remove `--exit-zero` / `--soft-fail` flags once the baseline findings have been reviewed and resolved.

### 11.7 Traceability Tags

Every `terraform apply` (baseline and projects) receives three environment variables injected by the workflow:

```
TF_VAR_git_sha     = GITHUB_SHA
TF_VAR_deployed_by = GITHUB_ACTOR
TF_VAR_repository  = GITHUB_REPOSITORY
```

These are declared as Terraform variables with `default = "local"` so that local runs work without CI context. In AWS, every Terraform-managed resource carries `git_sha`, `deployed_by`, and `repository` tags- enabling immediate traceability from an AWS resource back to the exact commit and actor that created or last modified it.

The AWS Account ID is masked in all CI logs via `::add-mask::` immediately after the STS call.

---

## 12. Security Model

| Control | Implementation |
|---|---|
| **Encryption at rest** | All S3 buckets and CloudWatch log groups encrypted with domain KMS CMK |
| **KMS explicit key policy** | Three-statement policy: root control, domain roles (via `PrincipalArn` condition), CloudWatch Logs service principal |
| **Encryption in transit** | `DenyInsecureTransport` bucket policy on all S3 buckets (HTTPS-only) |
| **No public S3 access** | `block_public_acls`, `block_public_policy`, `restrict_public_buckets` = `true` on all buckets |
| **Network isolation** | Glue jobs run in private VPC; no internet egress; S3 and Glue API via VPC endpoints |
| **VPC Flow Logs** | All VPC traffic captured; KMS-encrypted; 90-day retention |
| **Per-project IAM** | Each project has its own Glue execution role scoped to its S3 prefix |
| **EC2 scope** | `CreateNetworkInterface` scoped to domain subnet ARNs; no wildcard resources |
| **VPC Flow Logs IAM scope** | Policy resource scoped to the specific CloudWatch log group ARN |
| **No static credentials** | OIDC for CI/CD; no `AWS_ACCESS_KEY_ID` stored in GitHub |
| **OIDC token scope** | `id-token: write` only at job level in workflows that require AWS auth |
| **Account ID masking** | `::add-mask::` applied after STS call in all CI jobs |
| **Deterministic wheel versions** | Wheel versioned by commit SHA- no mutable `latest` alias |
| **Source file integrity** | `trap` restores `__init__.py` after `sed -i` version injection in CI |
| **Dependency auditing** | `pip-audit` scans for CVEs on every CI run touching Python deps |
| **SAST / IaC scanning** | Bandit (Python) + Checkov (Terraform/Dockerfile) on every relevant push |
| **Full Terraform plans on PRs** | Untruncated plan output posted as PR comment- no hidden changes |
| **Resource tagging** | `git_sha`, `deployed_by`, `repository` on all Terraform-managed resources |
| **S3 access logging** | All data bucket access logged to the dedicated `logs` bucket |
| **CloudTrail** | Provided at AWS Organisation level for account-wide API auditing |

For **open improvement tasks**, see [docs/tasks.md](docs/tasks.md).

---

## 13. Documentation Index

| Document | Description |
|---|---|
| [setup/README.md](setup/README.md) | Prerequisites, `bootstrap.sh` walkthrough, Terraform state setup, GitHub Secrets |
| [docs/architecture.md](docs/architecture.md) | Domain hierarchy, data layers, naming conventions, IAM model |
| [docs/creating-a-project.md](docs/creating-a-project.md) | Step-by-step guide: copy template → deploy first project |
| [docs/adding-a-job.md](docs/adding-a-job.md) | Step-by-step guide: write job script + Terraform → CI deploy |
| [docs/ci-cd.md](docs/ci-cd.md) | Branch strategy, workflow anatomy, OIDC setup, IAM trust policy template |
| [docs/terraform.md](docs/terraform.md) | Module hierarchy, remote state pattern, backend configuration |
| [docs/tasks.md](docs/tasks.md) | Engineering backlog- SecOps, DevOps, and Platform improvement tasks |

---

## 14. Contributing

1. Create a `feature/*` branch from `dev`.
2. Implement your changes, then run `make test lint` to verify locally.
3. Open a PR targeting `dev`. CI runs automatically- all checks must be green before merge is allowed.
4. After merging to `dev`, promote to `int` and then `main` via subsequent PRs through the standard review process.

---

## 15. Backlog & Improvement Tasks

Open engineering tasks are tracked in **[docs/tasks.md](docs/tasks.md)**, organised by area of responsibility:

- **SecOps**- Remaining IAM hardening, CI/CD role separation, supply chain security
- **DevOps**- Local credential safety guard, pipeline reliability improvements
- **Platform / DataOps**- Template completeness, onboarding automation, project metadata

---

## License

Proprietary. See [LICENSE](LICENSE) for details.
