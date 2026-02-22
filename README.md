# AWS Data Mesh Domain

> Production-ready mono-repository template for a single **AWS Data Mesh domain** — batteries included with AWS Glue 5.1, Apache Iceberg, Terraform IaC, and GitHub Actions CI/CD.

[![License](https://img.shields.io/badge/license-Proprietary-red.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.11-blue.svg)](https://www.python.org/)
[![Spark](https://img.shields.io/badge/spark-3.5-orange.svg)](https://spark.apache.org/)
[![Terraform](https://img.shields.io/badge/terraform-%3E%3D1.0-7B42BC.svg)](https://www.terraform.io/)

---

## Table of Contents

- [What It Does](#what-it-does)
- [Key Features](#key-features)
- [Repository Structure](#repository-structure)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Infrastructure](#infrastructure)
- [CI/CD](#cicd)
- [Documentation](#documentation)
- [Contributing](#contributing)

---

## What It Does

This repository is a **domain unit** inside an AWS Data Mesh. Each domain is
autonomous — it owns its data contracts, infrastructure, and deployment
pipeline. Within a domain you create **projects**, each project owning its own
Glue jobs, Iceberg tables, table optimizers, and Step Functions pipelines.

```
Domain  (this repository)
  └── Project  (e.g. sales, customers)
        ├── Tables         Raw (Hive) → Refined / Curated (Iceberg)
        ├── Glue Jobs      PySpark ETL using the shared core library
        ├── Optimizers     Iceberg compaction, orphan cleanup, snapshot retention
        └── Pipelines      Step Functions orchestration
```

Data flows through three S3 layers:

| Layer | Format | Purpose |
|-------|--------|---------|
| **raw** | Standard (Hive) | Landing zone — unmodified source data |
| **refined** | Iceberg | Cleaned, conformed, joinable |
| **curated** | Iceberg | Business-ready, aggregated outputs |

---

## Key Features

- **Zero environment literals in job code** — `get_config()` resolves all
  bucket names, database names, and environment settings at runtime.
- **Single source of truth** — `setup/domain.json` drives every name, prefix,
  and convention across Terraform, CI/CD, and Python code.
- **Per-project IAM isolation** — each project gets a scoped Glue execution
  role, preventing cross-project data access.
- **Smart CI/CD** — path-based change detection avoids rebuilding the wheel or
  re-running Terraform when only unrelated files change.
- **OIDC authentication** — no static AWS credentials stored in GitHub; all
  deployments assume IAM roles via GitHub's OIDC provider.
- **Local Spark parity** — Docker image mirrors the Glue 5.1 runtime
  (Python 3.11, Spark 3.5, OpenJDK 17) for local development and testing.
- **Iceberg-native** — table optimizers (compaction, orphan file cleanup,
  snapshot expiry) are provisioned automatically alongside every Iceberg table.

---

## Repository Structure

```
.
├── setup/
│   ├── domain.json              # Single source of truth (domain name, abbr, region)
│   ├── bootstrap.sh             # One-time local environment setup (idempotent)
│   └── init-terraform.sh        # Generate Terraform backend configs from domain.json
├── src/
│   ├── core/                    # Shared Python library — built as .whl, used by all jobs
│   │   ├── config/settings.py   # Runtime config resolver (env vars → domain.json)
│   │   ├── spark/session.py     # SparkSession factory
│   │   ├── io/                  # Iceberg readers / writers
│   │   ├── iceberg/catalog.py   # Glue catalog helpers
│   │   └── logging/logger.py    # Structured logger
│   └── jobs/                    # Standalone Glue job scripts (NOT packaged in the wheel)
│       └── <project>/job_<name>.py
├── tests/                       # pytest unit tests for the core library and jobs
├── infrastructure/
│   ├── modules/                 # Reusable Terraform modules (glue_job, glue_iceberg_table, …)
│   ├── foundation/              # Shared infra — S3 buckets, IAM, Glue databases
│   ├── projects/                # Per-project stacks — tables, jobs, optimizers, pipelines
│   │   └── _template/           # Copy this to bootstrap a new project
│   └── environments/
│       ├── dev/
│       ├── int/
│       └── prod/
├── docs/                        # Deep-dive documentation
├── Dockerfile                   # Local Spark dev image (mirrors Glue 5.1)
├── Makefile                     # Developer task runner
└── pyproject.toml               # Python project metadata and tool config

```

---

## Getting Started

### Prerequisites

- Ubuntu 24.04+ or WSL2
- `sudo` access (for the bootstrap script)
- AWS CLI configured with credentials for the target account
- An S3 bucket for Terraform state — see [setup/README.md](setup/README.md)

### 1. Configure your domain

Edit `setup/domain.json` before running anything else:

```json
{
  "domain_name": "finance01",
  "domain_abbr": "f01",
  "aws_region": "eu-west-1"
}
```

All resource names (S3 buckets, Glue databases, IAM roles, job names) derive
from this file.

### 2. Bootstrap the local environment

```bash
./setup/bootstrap.sh
```

This single idempotent script installs Java 17, Python 3.11, Spark 3.5.6,
Terraform, AWS CLI v2, and UV; creates a `.venv`; installs all Python
dependencies; and generates a `.env` file for local development.

Or, to use Docker instead:

```bash
make bootstrap-docker
```

### 3. Initialise Terraform

```bash
./setup/init-terraform.sh      # generates backend.conf for dev / int / prod
make terraform-init-dev        # initialises the dev workspace
```

See [setup/README.md](setup/README.md) for the full step-by-step guide,
including how to provision the required Terraform state S3 buckets.

---

## Development Workflow

### Run tests

```bash
make test           # pytest with coverage
make lint           # ruff check + format check
make typecheck      # mypy on src/core/
make format         # auto-fix formatting issues
```

### Run a job locally

```bash
# Via Python (requires .venv activated)
make run-local JOB=project01/job_teste.py

# Via Docker (mirrors Glue 5.1 exactly)
make docker-build
make docker-run JOB=project01/job_teste.py
```

### Writing a job

Every job follows the same pattern using the `core` library:

```python
from core.spark.session import get_spark
from core.config.settings import get_config
from core.io.readers import read_iceberg
from core.io.writers import write_iceberg
from core.logging.logger import get_logger

def main() -> None:
    spark = get_spark(app_name="myproject-myjob")
    cfg   = get_config()
    log   = get_logger(__name__)

    df = read_iceberg(spark, catalog_db=cfg["refined_db"], table="source_table")

    # ... your PySpark transformations ...

    write_iceberg(df=result, table=f"glue_catalog.{cfg['curated_db']}.target", mode="append")
    spark.stop()

if __name__ == "__main__":
    main()
```

Key rules:
- **No `awsglue` imports** — use `core` abstractions only.
- **No environment literals** — `get_config()` handles it.
- Job scripts live in `src/jobs/<project>/` and are **not** included in the
  wheel; they are uploaded to S3 as standalone `.py` files.

### Build and upload artifacts

```bash
make build                         # build core-latest-py3-none-any.whl
make upload-wheel ENVIRONMENT=dev  # build + upload wheel to S3
make upload-jobs  ENVIRONMENT=dev  # sync job scripts to S3
```

---

## Infrastructure

Infrastructure is managed with Terraform and split into three layers:

| Layer | Path | What it provisions |
|-------|------|--------------------|
| **Foundation** | `infrastructure/foundation/` | S3 buckets, Glue databases, shared IAM roles |
| **Projects** | `infrastructure/projects/<name>/` | Glue jobs, Iceberg tables, optimizers, Step Functions |
| **Environments** | `infrastructure/environments/<env>/` | Root module that wires foundation + all projects for one AWS account |

### Adding a project

```bash
cp -r infrastructure/projects/_template infrastructure/projects/myproject
mkdir -p src/jobs/myproject
```

Then fill in the Terraform files and wire the new module into
`infrastructure/projects/main.tf`. Full walkthrough: [docs/creating-a-project.md](docs/creating-a-project.md).

### Terraform commands

```bash
make terraform-plan-dev    # plan changes for Dev
make terraform-plan-int    # plan changes for Int
make terraform-plan-prod   # plan changes for Prod
make terraform-apply ENVIRONMENT=dev   # apply for a specific environment
make terraform-validate    # validate all environments
```

---

## CI/CD

All pipelines run in GitHub Actions. Branch flow:

```
feature/*  ──PR──▶  dev  ──PR──▶  int  ──PR──▶  main (prod)
                     │              │               │
                  Deploy Dev    Deploy Int     Deploy Prod
```

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| `ci.yml` | Every push / PR | Lint, type-check, test, Terraform validate, wheel build |
| `deploy-dev.yml` | Push to `dev` | Deploy to Dev AWS account |
| `deploy-int.yml` | Push to `int` | Deploy to Int AWS account |
| `deploy-prod.yml` | Push to `main` | Deploy to Prod (manual approval gate) |

Deployments use a three-phase order — foundation → artifacts upload →
full Terraform apply — so S3 buckets always exist before jobs reference them.

Authentication uses **GitHub OIDC** (no stored credentials). Each environment
needs one GitHub secret:

| Environment | Secret | Value |
|-------------|--------|-------|
| `dev` | `AWS_ROLE_ARN_DEV` | `arn:aws:iam::<account>:role/<role>` |
| `int` | `AWS_ROLE_ARN_INT` | `arn:aws:iam::<account>:role/<role>` |
| `prod` | `AWS_ROLE_ARN_PROD` | `arn:aws:iam::<account>:role/<role>` |

See [docs/ci-cd.md](docs/ci-cd.md) for the full setup, including the required
IAM trust policy.

---

## Documentation

| Document | Description |
|----------|-------------|
| [setup/README.md](setup/README.md) | Prerequisites, bootstrap, first-time setup |
| [docs/architecture.md](docs/architecture.md) | Domain hierarchy, data layers, naming conventions |
| [docs/creating-a-project.md](docs/creating-a-project.md) | How to add a new project to the domain |
| [docs/adding-a-job.md](docs/adding-a-job.md) | How to add a new Glue job to an existing project |
| [docs/ci-cd.md](docs/ci-cd.md) | Branch strategy, workflows, OIDC setup |
| [docs/terraform.md](docs/terraform.md) | Module hierarchy, foundation vs projects |

---

## Contributing

1. **Fork** the repository and create a branch from `dev`.
2. Make your changes, ensuring `make test lint typecheck` all pass.
3. Open a pull request targeting the `dev` branch.
4. The CI workflow runs automatically; all checks must be green before merge.

### Common tasks

```bash
make help     # list all available make targets
make test     # run tests
make lint     # lint and format-check
make format   # auto-fix formatting
```

### Maintainers

This repository is maintained by the **Data Engineering Team**.
For questions or issues, open a GitHub Issue or reach out via your
team's internal communication channel.

---

## License

Proprietary. See [LICENSE](LICENSE) for details.