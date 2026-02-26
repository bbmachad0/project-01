"""<project> - Example Glue job template.

This file demonstrates the standard pattern for writing a Glue job
using only ``core`` abstractions.  Copy it into your project's
``src/jobs/<project>/`` directory and rename to ``job_<name>.py``.

Key rules:
  - No ``awsglue`` imports - use ``core`` only.
  - No environment branching - ``get_spark()`` and ``get_config()``
    handle local vs. Glue differences automatically.
  - No hardcoded bucket names - ``get_config()`` resolves them.
"""

from dp_foundation.config.settings import get_config
from dp_foundation.io.readers import read_iceberg
from dp_foundation.io.writers import write_iceberg
from dp_foundation.logging.logger import get_logger
from dp_foundation.spark.session import get_spark


def main() -> None:
    spark = get_spark(app_name="<project>-<name>")
    cfg = get_config()
    log = get_logger(__name__)

    log.info("Starting <name> job")

    # ── Extract ──────────────────────────────────────────────────
    df = read_iceberg(
        spark,
        f"glue_catalog.{cfg['iceberg_database_refined']}.<source_table>",
    )

    # ── Transform ────────────────────────────────────────────────
    result = df  # replace with your PySpark transformations

    # ── Load ─────────────────────────────────────────────────────
    write_iceberg(
        df=result,
        table=f"glue_catalog.{cfg['iceberg_database_curated']}.<target_table>",
        mode="append",
    )

    log.info("<name> job complete")
    spark.stop()


if __name__ == "__main__":
    main()
