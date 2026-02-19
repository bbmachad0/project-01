"""Iceberg table utilities - DDL helpers, maintenance, and metadata ops.

All functions use *pure PySpark SQL* and accept a standard
``SparkSession``.  No ``awsglue`` imports.

Usage::

    from core.iceberg.catalog import (
        create_table_if_not_exists,
        expire_snapshots,
        rewrite_data_files,
    )
    create_table_if_not_exists(spark, "glue_catalog.nl_curated.orders", schema_ddl)
"""

from __future__ import annotations

from typing import Optional, Sequence

from pyspark.sql import SparkSession


def create_table_if_not_exists(
    spark: SparkSession,
    table: str,
    schema_ddl: str,
    partition_spec: Optional[str] = None,
    table_properties: Optional[dict] = None,
    location: Optional[str] = None,
) -> None:
    """Create an Iceberg table if it does not already exist.

    Parameters
    ----------
    spark:
        Active Spark session.
    table:
        Fully-qualified table name (e.g. ``glue_catalog.nl_curated.orders``).
    schema_ddl:
        Column definitions in Spark DDL syntax, e.g.
        ``"id BIGINT, name STRING, ts TIMESTAMP"``.
    partition_spec:
        Optional Iceberg partition spec (e.g. ``"days(ts)"``) appended to
        the ``PARTITIONED BY`` clause.
    table_properties:
        Optional dictionary of Iceberg table properties.
    location:
        Optional explicit S3 location for the table data.
    """
    stmt = f"CREATE TABLE IF NOT EXISTS {table} ({schema_ddl}) USING iceberg"

    if partition_spec:
        stmt += f" PARTITIONED BY ({partition_spec})"

    if location:
        stmt += f" LOCATION '{location}'"

    if table_properties:
        props = ", ".join(f"'{k}'='{v}'" for k, v in table_properties.items())
        stmt += f" TBLPROPERTIES ({props})"

    spark.sql(stmt)


def expire_snapshots(
    spark: SparkSession,
    table: str,
    older_than_ts: str,
    retain_last: int = 5,
) -> None:
    """Expire old Iceberg snapshots to reclaim storage.

    Parameters
    ----------
    table:
        Fully-qualified Iceberg table.
    older_than_ts:
        ISO-8601 timestamp string.
    retain_last:
        Minimum number of snapshots to keep.
    """
    spark.sql(
        f"CALL glue_catalog.system.expire_snapshots("
        f"table => '{table}', "
        f"older_than => TIMESTAMP '{older_than_ts}', "
        f"retain_last => {retain_last})"
    )


def rewrite_data_files(
    spark: SparkSession,
    table: str,
    strategy: str = "binpack",
    target_file_size_bytes: int = 536_870_912,  # 512 MB
) -> None:
    """Compact small files in an Iceberg table.

    Parameters
    ----------
    table:
        Fully-qualified Iceberg table.
    strategy:
        Compaction strategy - ``binpack`` or ``sort``.
    target_file_size_bytes:
        Target output file size.
    """
    spark.sql(
        f"CALL glue_catalog.system.rewrite_data_files("
        f"table => '{table}', "
        f"strategy => '{strategy}', "
        f"options => map('target-file-size-bytes', '{target_file_size_bytes}'))"
    )


def list_snapshots(
    spark: SparkSession,
    table: str,
) -> list:
    """Return snapshot metadata as a list of Row objects."""
    return spark.sql(f"SELECT * FROM {table}.snapshots").collect()


def drop_table(
    spark: SparkSession,
    table: str,
    purge: bool = False,
) -> None:
    """Drop an Iceberg table."""
    purge_clause = " PURGE" if purge else ""
    spark.sql(f"DROP TABLE IF EXISTS {table}{purge_clause}")
