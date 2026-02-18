# Adding a Glue Job

This guide covers adding a new job to an **existing** project. If the project
does not exist yet, see [creating-a-project.md](creating-a-project.md) first.

---

## 1. Create the job script

```bash
touch src/jobs/<project>/job_<name>.py
```

Use the standard structure:

```python
"""<project> - <short description>."""

import sys

from core.spark.session import get_spark
from core.config.settings import get_config
from core.io.readers import read_iceberg
from core.io.writers import write_iceberg
from core.logging.logger import get_logger


def main() -> None:
    spark = get_spark(app_name="<project>-<name>")
    cfg = get_config()
    log = get_logger(__name__)

    log.info("Starting <name> job")

    # ── Extract ──────────────────────────────────
    df = read_iceberg(spark, catalog_db=cfg["refined_db"], table="<source>")

    # ── Transform ────────────────────────────────
    result = df  # your PySpark transformations here

    # ── Load ─────────────────────────────────────
    write_iceberg(
        df=result,
        path=f"s3://{cfg['s3_curated_bucket']}/iceberg/<target>",
        catalog_db=cfg["curated_db"],
        table="<target>",
        mode="append",
    )

    log.info("<name> job complete")
    spark.stop()


if __name__ == "__main__":
    main()
```

### Key rules

- **No `awsglue` imports** - use `core` abstractions only.
- **No environment branching** - `get_spark()` and `get_config()` handle it.
- Job scripts are **not packaged in the wheel** - they are uploaded to S3 as
  standalone `.py` files.

---

## 2. Add Terraform resources

Edit `infrastructure/projects/<project>/jobs.tf`:

```hcl
module "job_<name>" {
  source = "../../modules/glue_job"

  job_name       = "${var.domain_abbr}-${var.project_slug}-<name>-${var.env}"
  script_location = "s3://${var.artifacts_bucket}/scripts/jobs/<project>/job_<name>.py"
  extra_py_files  = "s3://${var.artifacts_bucket}/wheels/core-latest-py3-none-any.whl"
  role_arn        = module.iam_glue_<project>.role_arn

  default_arguments = {
    "--ENV"         = var.env
    "--CONFIG_PATH" = ""
  }
}
```

If the job writes to a **new table**, also add entries in:

- `tables.tf` - table definition (Standard or Iceberg)
- `optimizers.tf` - compaction / orphan cleanup for Iceberg tables

---

## 3. Add unit tests

```bash
touch tests/test_<name>.py
```

Test the transformation logic in isolation using plain PySpark DataFrames.
Avoid testing Glue-specific behaviour.

---

## 4. Add to pipeline (optional)

If the job should be orchestrated with other jobs, add it to the
StepFunctions definition in `pipelines.tf`.

---

## 5. Validate & deploy

```bash
make test
make lint
make terraform-plan-dev
```

Open a PR targeting `dev`. The CI pipeline will validate everything. Once
merged, the deploy workflow uploads the new script to S3 and applies Terraform.
