# Architecture

## Domain Hierarchy

This repository represents a single **domain** inside an AWS Data Mesh.
Each domain is an autonomous unit with its own data, infrastructure, and CI/CD.

```
Domain  (this repository)
  └── Project  (e.g. sales, customers, legacy_refactor)
        ├── Tables         Standard tables in RAW; Iceberg elsewhere
        ├── Glue Jobs      Read/write from tables
        ├── Optimizers     Compaction, orphan cleanup, snapshot retention
        └── Pipelines      StepFunctions orchestration
```

---

## `setup/domain.json` - Single Source of Truth

Every name, prefix, and convention derives from one file at `setup/domain.json`:

```json
{
  "domain_name": "finance01",
  "domain_abbr": "f01",
  "aws_region": "eu-west-1"
}
```

| Field | Usage |
|-------|-------|
| `domain_name` | Human-readable name, Terraform descriptions |
| `domain_abbr` | S3 buckets, Glue databases (`f01_de_raw`), job names |
| `aws_region` | Provider region, `.env` generation |

Edit this file **once** before running `setup/bootstrap.sh` to adapt the
repository for a different domain.

---

## Data Layers

S3 bucket naming follows the AWS-recommended convention:
`{domain_abbr}-{purpose}-{account_id}-{country_code}-{env}`

The `account_id` is resolved dynamically from AWS credentials - it is
never hardcoded.

| Layer | S3 Bucket | Glue Database | Table Format |
|-------|-----------|---------------|--------------|
| **raw** | `{abbr}-raw-{account_id}-{cc}-{env}` | `{abbr}_{cc}_raw` | Standard (Hive) |
| **refined** | `{abbr}-refined-{account_id}-{cc}-{env}` | `{abbr}_{cc}_refined` | Standard / Iceberg |
| **curated** | `{abbr}-curated-{account_id}-{cc}-{env}` | `{abbr}_{cc}_curated` | Iceberg |

An `artifacts` bucket (`{abbr}-artifacts-{account_id}-{cc}-{env}`) stores wheels
and job scripts.

---

## Naming Conventions

| Resource | Pattern | Example |
|----------|---------|---------|
| S3 bucket | `{abbr}-{purpose}-{account_id}-{country_code}-{env}` | `f01-raw-390403879405-de-dev` |
| Glue database | `{abbr}_{country_code}_{layer}` | `f01_de_raw` |
| Glue job | `{abbr}-{project_name}-{job}-{env}` | `f01-pj01-daily-sales-dev` |
| Pipeline | `{abbr}-{project_name}-pipeline-{env}` | `f01-pj01-pipeline-dev` |
| IAM role (Glue) | `{abbr}-glue-{project_name}-{env}` | `f01-glue-pj01-dev` |
| IAM role (Optimizer) | `{abbr}-optimizer-{project_name}-{env}` | `f01-optimizer-pj01-dev` |
| S3 data prefix | `{bucket}/{project_name}/...` | `f01-raw-390403879405-de-dev/pj01/...` |
| Iceberg table path | `s3://{bucket}/{project_name}/{db}/{table}` | |

Each project declares a **`project_name`** (short, unique abbreviation) used
in all resource names to avoid collisions.

### Per-Project IAM Isolation

IAM roles are created **per project**, not per domain.  Each project's
`iam.tf` instantiates a Glue execution role and a Table Optimizer role
scoped to:

- **S3**: object access restricted to `{bucket}/{project_name}/*` on data
  buckets (raw, refined, curated).  The artifacts bucket gets read-only
  access plus temp-dir write.
- **Glue Catalog**: domain-wide (`{domain_abbr}_{country_code}_*` databases) because
  databases are shared across projects within the domain.
- **SSM**: parameters under `/{project_name}/*`.

This gives each project a "plug-and-play" role that is generic enough
to avoid per-job policies, yet specific enough to prevent cross-project
data access.

---

## Shared Python Library - `dp_foundation`

The `dp_foundation` package is maintained in the standalone repository
[`org-data-platform-foundation`](https://github.com/ORG/org-data-platform-foundation).
It is built as a wheel (`data_platform_foundation-{version}-py3-none-any.whl`),
published as a GitHub Release asset, downloaded by this domain's CI/CD,
uploaded to S3, and referenced via `--extra-py-files` on every Glue job.

```
dp_foundation/
├── spark/      get_spark() - local vs Glue session factory
├── config/     get_config() - env-prefix-aware configuration
├── io/         read_*, write_*, merge_iceberg
├── iceberg/    DDL, maintenance (compaction, snapshot expiry)
└── logging/    get_logger() - JSON or text structured logging
```

Jobs import from `dp_foundation` - never from `awsglue` directly:

```python
from dp_foundation.spark.session import get_spark
from dp_foundation.io.writers import write_iceberg
```

---

## Environment Strategy

| Environment | AWS Account | Branch | Deployment |
|-------------|-------------|--------|------------|
| `local` | None | Any | `make run-local` |
| `dev` | Dev account | `dev` | Automatic on merge |
| `int` | Int account | `int` | Automatic on merge |
| `prod` | Prod account | `main` | Manual approval + merge |

The `ENV` variable (`local`, `dev`, `int`, `prod`) controls Spark session
creation, S3 bucket resolution, and logging level. No environment-specific
logic exists inside any job file.
