"""Generic DataFrame writers - pure PySpark, no Glue dependencies.

Each writer accepts a standard ``pyspark.sql.DataFrame`` and persists
it to the requested target.  All Iceberg-specific SQL (MERGE, etc.)
is encapsulated here so that job files stay declarative.

Usage::

    from core.io.writers import write_iceberg, write_parquet
    write_iceberg(df, "glue_catalog.{abbr}_curated.daily_sales", mode="append")
    write_parquet(df, "s3://bucket/curated/daily_sales/", mode="overwrite")
"""

from __future__ import annotations

from collections.abc import Sequence

from pyspark.sql import DataFrame

# ---------------------------------------------------------------------------
# Iceberg
# ---------------------------------------------------------------------------


def write_iceberg(
    df: DataFrame,
    table: str,
    mode: str = "append",
    partition_by: Sequence[str] | None = None,
    sort_by: Sequence[str] | None = None,
) -> None:
    """Write a DataFrame to an Iceberg table.

    Parameters
    ----------
    df:
        Source DataFrame.
    table:
        Fully-qualified Iceberg table reference
        (e.g. ``glue_catalog.{abbr}_curated.daily_sales``).
    mode:
        Spark write mode - ``append``, ``overwrite``, or ``error``.
    partition_by:
        Optional list of partition columns (Iceberg hidden partitioning
        is preferred; use only when explicit partitioning is required).
    sort_by:
        Optional list of sort-order columns written into file metadata.
    """
    writer = df.writeTo(table)

    if partition_by:
        # Iceberg v2 partitioning via writeTo API
        writer = writer.partitionedBy(*partition_by)

    if sort_by:
        writer = writer.tableProperty("write.sort-order", ",".join(sort_by))

    if mode == "overwrite":
        writer.overwritePartitions()
    elif mode == "append":
        writer.append()
    elif mode == "create_or_replace":
        writer.createOrReplace()
    else:
        writer.append()


def merge_iceberg(
    spark,
    source_df: DataFrame,
    target_table: str,
    merge_key: str,
) -> None:
    """Execute an Iceberg MERGE INTO from *source_df* into *target_table*.

    A unique temporary view name is generated per call to avoid collisions
    when multiple MERGE operations run concurrently in the same SparkSession.

    Parameters
    ----------
    spark:
        Active SparkSession (needed for SQL execution).
    source_df:
        Incoming rows.
    target_table:
        Fully-qualified Iceberg table.
    merge_key:
        Column name used as the join key - must exist in both DataFrames.
    """
    import uuid

    temp_view = f"_merge_src_{uuid.uuid4().hex}"
    source_df.createOrReplaceTempView(temp_view)

    columns = source_df.columns
    update_set = ", ".join(f"t.{c} = s.{c}" for c in columns if c != merge_key)
    insert_cols = ", ".join(columns)
    insert_vals = ", ".join(f"s.{c}" for c in columns)

    sql = f"""
        MERGE INTO {target_table} AS t
        USING {temp_view} AS s
        ON t.{merge_key} = s.{merge_key}
        WHEN MATCHED THEN UPDATE SET {update_set}
        WHEN NOT MATCHED THEN INSERT ({insert_cols}) VALUES ({insert_vals})
    """
    spark.sql(sql)


# ---------------------------------------------------------------------------
# Parquet / Generic
# ---------------------------------------------------------------------------


def write_parquet(
    df: DataFrame,
    path: str,
    mode: str = "overwrite",
    partition_by: Sequence[str] | None = None,
    coalesce: int | None = None,
) -> None:
    """Write a DataFrame as Parquet files.

    Parameters
    ----------
    df:
        Source DataFrame.
    path:
        S3 URI or local filesystem path.
    mode:
        Spark write mode.
    partition_by:
        Optional partition columns.
    coalesce:
        Optional number of output files.
    """
    if coalesce:
        df = df.coalesce(coalesce)

    writer = df.write.format("parquet").mode(mode)

    if partition_by:
        writer = writer.partitionBy(*partition_by)

    writer.save(path)
