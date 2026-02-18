"""Glue Job — Daily Sales Aggregation

Reads raw sales events from the Iceberg ``nl_raw.sales_events`` table,
computes daily aggregates (revenue, quantity, transaction count), and
writes the result to ``nl_curated.daily_sales``.

Scheduling: triggered daily by StepFunctions pipeline.
"""

import sys

from pyspark.sql import functions as F

from core.spark.session import get_spark
from core.config.settings import get_config
from core.logging.logger import get_logger
from core.io.readers import read_iceberg
from core.io.writers import write_iceberg

logger = get_logger(__name__)


def transform_daily_sales(df):
    """Aggregate raw sales events into a daily summary.

    Parameters
    ----------
    df : pyspark.sql.DataFrame
        Raw sales events with at least: ``event_ts``, ``amount``,
        ``quantity``, ``product_id``, ``store_id``.

    Returns
    -------
    pyspark.sql.DataFrame
        Aggregated daily sales.
    """
    return (
        df.withColumn("sale_date", F.to_date("event_ts"))
        .groupBy("sale_date", "store_id", "product_id")
        .agg(
            F.sum("amount").alias("total_revenue"),
            F.sum("quantity").alias("total_quantity"),
            F.count("*").alias("transaction_count"),
        )
    )


def main() -> None:
    cfg = get_config()
    spark = get_spark()

    logger.info(
        "Starting job_daily_sales in env=%s",
        cfg["env"],
    )

    raw_table = f"glue_catalog.{cfg['iceberg_database_raw']}.sales_events"
    curated_table = f"glue_catalog.{cfg['iceberg_database_curated']}.daily_sales"

    logger.info("Reading from %s", raw_table)
    raw_df = read_iceberg(spark, raw_table)

    logger.info("Transforming daily sales aggregates")
    result_df = transform_daily_sales(raw_df)

    logger.info("Writing to %s", curated_table)
    write_iceberg(result_df, curated_table, mode="append")

    logger.info("job_daily_sales completed successfully")
    spark.stop()


if __name__ == "__main__":
    main()
