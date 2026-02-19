"""Spark session factory - environment-agnostic entry point.

Usage in any Glue job or local script::

    from core.spark.session import get_spark
    spark = get_spark()

The factory inspects the ``ENV`` environment variable to decide
whether to bootstrap a local PySpark session (with Iceberg + Glue
Catalog extensions) or to reuse the runtime session provided by
the AWS Glue service.

Supported ``ENV`` values:
    - ``local``  - standalone PySpark with Iceberg on Glue Catalog
    - ``dev`` / ``int`` / ``prod`` - AWS Glue managed runtime
"""

from __future__ import annotations

import os

from pyspark.sql import SparkSession

from core.config.settings import _ABBR

_ENV_KEY = "ENV"
_LOCAL_ENV = "local"

# Iceberg / Glue Catalog Maven coordinates shipped with Glue 5.1
_ICEBERG_SPARK_JAR = "org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.7.1"
_AWS_BUNDLE_JAR = "software.amazon.awssdk:bundle:2.29.45"


def _is_local() -> bool:
    """Return *True* when running outside an AWS Glue environment."""
    return os.getenv(_ENV_KEY, _LOCAL_ENV).lower() == _LOCAL_ENV


def _build_local_session(
    app_name: str,
    warehouse_path: str,
    glue_catalog_id: str | None = None,
) -> SparkSession:
    """Create a local SparkSession configured for Iceberg + Glue Catalog.

    Parameters
    ----------
    app_name:
        Spark application name shown in the UI.
    warehouse_path:
        S3 or local path used as the default Iceberg warehouse.
    glue_catalog_id:
        Optional AWS account ID for the Glue Data Catalog.  When *None*
        the SDK resolves the caller identity automatically.
    """
    builder = (
        SparkSession.builder.appName(app_name)
        .master("local[*]")
        .config(
            "spark.jars.packages",
            f"{_ICEBERG_SPARK_JAR},{_AWS_BUNDLE_JAR}",
        )
        # Iceberg Spark extensions
        .config(
            "spark.sql.extensions",
            "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions",
        )
        # Catalog - backed by AWS Glue
        .config("spark.sql.catalog.glue_catalog", "org.apache.iceberg.spark.SparkCatalog")
        .config(
            "spark.sql.catalog.glue_catalog.catalog-impl",
            "org.apache.iceberg.aws.glue.GlueCatalog",
        )
        .config("spark.sql.catalog.glue_catalog.warehouse", warehouse_path)
        .config(
            "spark.sql.catalog.glue_catalog.io-impl",
            "org.apache.iceberg.aws.s3.S3FileIO",
        )
        # Default catalog for unqualified table references
        .config("spark.sql.defaultCatalog", "glue_catalog")
        # Performance / correctness defaults
        .config("spark.sql.sources.partitionOverwriteMode", "dynamic")
        .config("spark.sql.adaptive.enabled", "true")
        .config("spark.sql.iceberg.handle-timestamp-without-timezone", "true")
    )

    if glue_catalog_id:
        builder = builder.config("spark.sql.catalog.glue_catalog.glue.id", glue_catalog_id)

    return builder.getOrCreate()


def _build_glue_session() -> SparkSession:
    """Retrieve the active SparkSession provided by the Glue runtime.

    In AWS Glue 5.1+ the runtime pre-creates the session with the job
    bookmark, Iceberg, and catalog configuration already applied.
    Calling ``getOrCreate()`` returns that existing session.
    """
    return SparkSession.builder.getOrCreate()


def get_spark(
    app_name: str = f"{_ABBR}-glue-job",
    warehouse_path: str = f"s3://{_ABBR}-warehouse/iceberg/",
    glue_catalog_id: str | None = None,
) -> SparkSession:
    """Return an environment-appropriate SparkSession.

    This is the **only** function jobs should call to obtain a session.

    Parameters
    ----------
    app_name:
        Application name (used in local mode only).
    warehouse_path:
        Default Iceberg warehouse path (local mode only).
    glue_catalog_id:
        AWS account ID for the Glue Catalog (local mode only).
    """
    if _is_local():
        return _build_local_session(app_name, warehouse_path, glue_catalog_id)
    return _build_glue_session()
