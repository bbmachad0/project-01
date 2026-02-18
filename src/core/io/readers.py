"""Generic DataFrame readers — pure PySpark, no Glue dependencies.

Each reader returns a standard ``pyspark.sql.DataFrame`` and accepts
only a :class:`SparkSession` plus read-specific parameters.

Usage::

    from core.io.readers import read_iceberg, read_parquet
    df = read_iceberg(spark, "glue_catalog.nl_raw.orders")
    df = read_parquet(spark, "s3://bucket/raw/events/")
"""

from __future__ import annotations

from typing import Optional, Sequence

from pyspark.sql import DataFrame, SparkSession


def read_iceberg(
    spark: SparkSession,
    table: str,
    snapshot_id: Optional[int] = None,
    columns: Optional[Sequence[str]] = None,
) -> DataFrame:
    """Read an Iceberg table via Spark SQL catalog.

    Parameters
    ----------
    spark:
        Active Spark session.
    table:
        Fully-qualified Iceberg table reference
        (e.g. ``glue_catalog.nl_curated.customers``).
    snapshot_id:
        Optional Iceberg snapshot for time-travel queries.
    columns:
        Optional column projection pushed down before reading.
    """
    reader = spark.read.format("iceberg")

    if snapshot_id is not None:
        reader = reader.option("snapshot-id", str(snapshot_id))

    df = reader.load(table)

    if columns:
        df = df.select(*columns)

    return df


def read_parquet(
    spark: SparkSession,
    path: str,
    schema: Optional[str] = None,
    columns: Optional[Sequence[str]] = None,
) -> DataFrame:
    """Read Parquet files from an S3 or local path.

    Parameters
    ----------
    spark:
        Active Spark session.
    path:
        S3 URI or local filesystem path.
    schema:
        Optional DDL schema string for strict typing.
    columns:
        Optional column projection.
    """
    reader = spark.read.format("parquet")

    if schema:
        reader = reader.schema(schema)

    df = reader.load(path)

    if columns:
        df = df.select(*columns)

    return df


def read_csv(
    spark: SparkSession,
    path: str,
    header: bool = True,
    delimiter: str = ",",
    schema: Optional[str] = None,
) -> DataFrame:
    """Read CSV files from an S3 or local path.

    Parameters
    ----------
    spark:
        Active Spark session.
    path:
        S3 URI or local filesystem path.
    header:
        Whether the first row contains column names.
    delimiter:
        Field separator character.
    schema:
        Optional DDL schema string.
    """
    reader = (
        spark.read.format("csv")
        .option("header", str(header).lower())
        .option("delimiter", delimiter)
        .option("inferSchema", "true" if schema is None else "false")
    )

    if schema:
        reader = reader.schema(schema)

    return reader.load(path)


def read_json(
    spark: SparkSession,
    path: str,
    multiline: bool = False,
    schema: Optional[str] = None,
) -> DataFrame:
    """Read JSON files from an S3 or local path."""
    reader = spark.read.format("json").option("multiLine", str(multiline).lower())

    if schema:
        reader = reader.schema(schema)

    return reader.load(path)
