"""Glue Job — Legacy Refactor Step 01

Example multi-step migration job.  Step 01 reads a legacy Parquet
dataset, applies schema alignment and data-quality filters, and
writes the cleaned output as an Iceberg table for downstream steps.

This pattern supports incremental migration of legacy pipelines into
the Data Mesh domain by splitting each pipeline into numbered steps.
"""

import sys

from pyspark.sql import functions as F
from pyspark.sql.types import (
    StructType,
    StructField,
    StringType,
    LongType,
    DoubleType,
)

from core.spark.session import get_spark
from core.config.settings import get_config
from core.logging.logger import get_logger
from core.io.readers import read_parquet
from core.io.writers import write_iceberg
from core.iceberg.catalog import create_table_if_not_exists

logger = get_logger(__name__)

_TARGET_SCHEMA_DDL = (
    "order_id BIGINT, customer_id BIGINT, product_id STRING, "
    "amount DOUBLE, order_ts TIMESTAMP, region STRING"
)


def align_schema(df):
    """Cast and rename legacy columns to match the target schema."""
    return (
        df.select(
            F.col("OrderID").cast("bigint").alias("order_id"),
            F.col("CustID").cast("bigint").alias("customer_id"),
            F.col("ProdCode").cast("string").alias("product_id"),
            F.col("Total").cast("double").alias("amount"),
            F.col("OrderDate").cast("timestamp").alias("order_ts"),
            F.col("Region").cast("string").alias("region"),
        )
        .filter(F.col("order_id").isNotNull())
        .filter(F.col("amount") > 0)
    )


def main() -> None:
    cfg = get_config()
    spark = get_spark()

    logger.info(
        "Starting job_step01 (legacy_refactor) in env=%s",
        cfg["env"],
    )

    source_path = f"s3://{cfg['s3_raw_bucket']}/legacy/orders/"
    target_table = f"glue_catalog.{cfg['iceberg_database_curated']}.legacy_orders"

    logger.info("Ensuring target table exists: %s", target_table)
    create_table_if_not_exists(
        spark,
        target_table,
        _TARGET_SCHEMA_DDL,
        partition_spec="days(order_ts)",
        table_properties={
            "write.format.default": "parquet",
            "write.parquet.compression-codec": "zstd",
        },
    )

    logger.info("Reading legacy Parquet from %s", source_path)
    raw_df = read_parquet(spark, source_path)

    logger.info("Aligning schema and filtering invalid rows")
    clean_df = align_schema(raw_df)

    row_count = clean_df.count()
    logger.info("Writing %d rows to %s", row_count, target_table)
    write_iceberg(clean_df, target_table, mode="append")

    logger.info("job_step01 completed successfully")
    spark.stop()


if __name__ == "__main__":
    main()
