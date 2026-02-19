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

## `domain.json` - Single Source of Truth

Every name, prefix, and convention derives from one file:

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
| `domain_abbr` | S3 buckets (`f01-raw-dev`), Glue databases (`f01_raw`), job names |
| `aws_region` | Provider region, `.env` generation |
| `python_version` | Bootstrap validation, CI matrix |
| `terraform_version` | CI validation, `required_version` |

---

## Data Layers

| Layer | S3 Bucket | Glue Database | Table Format |
|-------|-----------|---------------|--------------|
| **raw** | `{abbr}-raw-{env}` | `{abbr}_raw` | Standard (Hive) |
| **refined** | `{abbr}-refined-{env}` | `{abbr}_refined` | Iceberg |
| **curated** | `{abbr}-curated-{env}` | `{abbr}_curated` | Iceberg |

An `artifacts` bucket (`{abbr}-artifacts-{env}`) stores wheels, job scripts,
and Terraform state.

---

## Naming Conventions

| Resource | Pattern | Example |
|----------|---------|---------|
| S3 bucket | `{abbr}-{layer}-{env}` | `f01-raw-dev` |
| Glue database | `{abbr}_{layer}` | `f01_raw` |
| Glue job | `{abbr}-{project_slug}-{job}-{env}` | `f01-pj01-daily-sales-dev` |
| Pipeline | `{abbr}-{project_slug}-pipeline-{env}` | `f01-pj01-pipeline-dev` |
| IAM role (Glue) | `{abbr}-glue-{project_slug}-{env}` | `f01-glue-pj01-dev` |
| IAM role (Optimizer) | `{abbr}-optimizer-{project_slug}-{env}` | `f01-optimizer-pj01-dev` |
| S3 data prefix | `{bucket}/{project_slug}/...` | `f01-raw-dev/pj01/...` |
| Iceberg warehouse | `s3://{bucket}/{project_slug}/iceberg/` | |

Each project declares a **`project_slug`** (short, unique abbreviation) used
in all resource names to avoid collisions.

### Per-Project IAM Isolation

IAM roles are created **per project**, not per domain.  Each project's
`iam.tf` instantiates a Glue execution role and a Table Optimizer role
scoped to:

- **S3**: object access restricted to `{bucket}/{project_slug}/*` on data
  buckets (raw, curated, warehouse).  The artifacts bucket gets read-only
  access plus temp-dir write.
- **Glue Catalog**: domain-wide (`{domain_abbr}_*` databases) because
  databases are shared across projects within the domain.
- **SSM**: parameters under `/{project_slug}/*`.

This gives each project a "plug-and-play" role that is generic enough
to avoid per-job policies, yet specific enough to prevent cross-project
data access.

---

## Shared Python Library - `core`

The `src/core/` package is built as a wheel (`core-latest-py3-none-any.whl`)
and uploaded to S3. Every Glue job references it via `--extra-py-files`.

```
core/
├── spark/      get_spark() - local vs Glue session factory
├── config/     get_config() - env-prefix-aware configuration
├── io/         read_*, write_*, merge_iceberg
├── iceberg/    DDL, maintenance (compaction, snapshot expiry)
└── logging/    get_logger() - JSON or text structured logging
```

Jobs import from `core` - never from `awsglue` directly:

```python
from core.spark.session import get_spark
from core.io.writers import write_iceberg
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
