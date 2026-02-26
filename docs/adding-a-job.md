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

from dp_foundation.spark.session import get_spark
from dp_foundation.config.settings import get_config
from dp_foundation.io.readers import read_iceberg
from dp_foundation.io.writers import write_iceberg
from dp_foundation.logging.logger import get_logger


def main() -> None:
    spark = get_spark(app_name="<project>-<name>")
    cfg = get_config()
    log = get_logger(__name__)

    log.info("Starting <name> job")

    # ── Extract ──────────────────────────────────
    df = read_iceberg(spark, f"glue_catalog.{cfg['iceberg_database_refined']}.<source>")

    # ── Transform ────────────────────────────────
    result = df  # your PySpark transformations here

    # ── Load ─────────────────────────────────────
    write_iceberg(
        df=result,
        table=f"glue_catalog.{cfg['iceberg_database_curated']}.<target>",
        mode="append",
    )

    log.info("<name> job complete")
    spark.stop()


if __name__ == "__main__":
    main()
```

### Key rules

- **No `awsglue` imports** - use `dp_foundation` abstractions only.
- **No environment branching** - `get_spark()` and `get_config()` handle it.
- Job scripts are **not packaged in the wheel** - they are uploaded to S3 as
  standalone `.py` files.

---

## 2. Add Terraform resources

Edit `infrastructure/projects/<project>/jobs.tf`:

```hcl
module "job_<name>" {
  source = "../../modules/glue_job"

  job_name       = "${local.baseline.domain_abbr}-${local.config.name}-<name>-${var.environment}"
  script_s3_path = "s3://${local.baseline.s3_artifacts_bucket_id}/jobs/<project>/job_<name>.py"
  extra_py_files = "s3://${local.baseline.s3_artifacts_bucket_id}/wheels/data_platform_foundation-${var.wheel_version}-py3-none-any.whl"
  role_arn       = module.iam_glue_job.role_arn
  connections    = [local.baseline.glue_connection_name]

  default_arguments = {
    "--ENV" = var.environment
  }
}
```

If the job writes to a **new table**, also add entries in:

- `tables.tf` - table definition (Standard or Iceberg)

> **Note:** Iceberg table optimizers (compaction, snapshot retention, orphan
> file cleanup) are provisioned automatically by the `glue_iceberg_table`
> module - no manual entries in `optimizers.tf` are needed.

> **Note:** Glue `default_arguments` keys (without the `--` prefix) are
> automatically bridged to environment variables at runtime by `dp_foundation.config.args`.
> This means `--ENV dev` becomes `os.getenv("ENV") == "dev"` inside the job.

> **Note:** The `extra_py_files` reference uses `var.wheel_version`, which is
> set via `TF_VAR_wheel_version` in CI.  For local Terraform plans, the
> default value `"latest"` is used.

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
