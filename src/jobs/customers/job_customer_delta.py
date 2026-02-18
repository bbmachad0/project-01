"""Glue Job — Customer Delta (CDC) Processing

Reads incremental customer change events from ``nl_raw.customer_events``,
de-duplicates by ``customer_id`` (latest event wins), and merges the
result into the curated ``nl_curated.customers`` Iceberg table using a
MERGE INTO statement.

Scheduling: triggered by StepFunctions after upstream ingestion completes.
"""

import sys

from pyspark.sql import functions as F
from pyspark.sql.window import Window

from core.spark.session import get_spark
from core.config.settings import get_config
from core.logging.logger import get_logger
from core.io.readers import read_iceberg
from core.io.writers import merge_iceberg

logger = get_logger(__name__)


def deduplicate_events(df):
    """Keep only the most recent event per customer.

    Parameters
    ----------
    df : pyspark.sql.DataFrame
        Raw CDC events with ``customer_id``, ``event_ts``, and
        attribute columns.

    Returns
    -------
    pyspark.sql.DataFrame
        De-duplicated rows — one per customer.
    """
    window = Window.partitionBy("customer_id").orderBy(F.col("event_ts").desc())
    return (
        df.withColumn("_rn", F.row_number().over(window))
        .filter(F.col("_rn") == 1)
        .drop("_rn")
    )


def main() -> None:
    cfg = get_config()
    spark = get_spark()

    logger.info(
        "Starting job_customer_delta in env=%s",
        cfg["env"],
    )

    raw_table = f"glue_catalog.{cfg['iceberg_database_raw']}.customer_events"
    curated_table = f"glue_catalog.{cfg['iceberg_database_curated']}.customers"

    logger.info("Reading incremental events from %s", raw_table)
    raw_df = read_iceberg(spark, raw_table)

    logger.info("De-duplicating by customer_id")
    deduped_df = deduplicate_events(raw_df)

    logger.info("Merging into %s", curated_table)
    merge_iceberg(
        spark,
        source_df=deduped_df,
        target_table=curated_table,
        merge_key="customer_id",
    )

    logger.info("job_customer_delta completed successfully")
    spark.stop()


if __name__ == "__main__":
    main()
