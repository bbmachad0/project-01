"""Unit tests for job transformation functions.

These tests exercise *pure PySpark* transformation logic by creating
a local SparkSession.  No AWS services or Iceberg catalog required.
"""

import pytest
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import (
    StructType,
    StructField,
    StringType,
    LongType,
    DoubleType,
    TimestampType,
)

from jobs.sales.job_daily_sales import transform_daily_sales
from jobs.customers.job_customer_delta import deduplicate_events
from jobs.legacy_refactor.job_step01 import align_schema


@pytest.fixture(scope="session")
def spark():
    """Create a minimal local SparkSession for testing."""
    session = (
        SparkSession.builder
        .master("local[1]")
        .appName("unit-tests")
        .config("spark.sql.shuffle.partitions", "1")
        .config("spark.ui.enabled", "false")
        .config("spark.driver.bindAddress", "127.0.0.1")
        .getOrCreate()
    )
    yield session
    session.stop()


# ── Daily sales ──────────────────────────────────────────────────────

class TestTransformDailySales:
    def test_aggregates_by_date_store_product(self, spark):
        data = [
            ("2025-06-01 10:00:00", "S1", "P1", 100.0, 2),
            ("2025-06-01 11:00:00", "S1", "P1", 50.0, 1),
            ("2025-06-01 12:00:00", "S1", "P2", 200.0, 3),
            ("2025-06-02 09:00:00", "S1", "P1", 75.0, 1),
        ]
        df = spark.createDataFrame(
            data, ["event_ts", "store_id", "product_id", "amount", "quantity"]
        )
        result = transform_daily_sales(df)

        rows = {
            (r.sale_date.isoformat(), r.store_id, r.product_id): r
            for r in result.collect()
        }

        key = ("2025-06-01", "S1", "P1")
        assert rows[key].total_revenue == 150.0
        assert rows[key].total_quantity == 3
        assert rows[key].transaction_count == 2

    def test_single_event_produces_one_row(self, spark):
        data = [("2025-06-01 08:00:00", "S2", "P5", 42.0, 1)]
        df = spark.createDataFrame(
            data, ["event_ts", "store_id", "product_id", "amount", "quantity"]
        )
        result = transform_daily_sales(df)
        assert result.count() == 1


# ── Customer delta ───────────────────────────────────────────────────

class TestDeduplicateEvents:
    def test_keeps_latest_event_per_customer(self, spark):
        data = [
            (1, "2025-06-01 10:00:00", "Alice"),
            (1, "2025-06-02 12:00:00", "Alice Updated"),
            (2, "2025-06-01 08:00:00", "Bob"),
        ]
        df = spark.createDataFrame(data, ["customer_id", "event_ts", "name"])
        result = deduplicate_events(df)
        rows = {r.customer_id: r for r in result.collect()}

        assert len(rows) == 2
        assert rows[1].name == "Alice Updated"
        assert rows[2].name == "Bob"


# ── Legacy refactor schema alignment ────────────────────────────────

class TestAlignSchema:
    def test_renames_and_casts_columns(self, spark):
        data = [
            (1001, 500, "ABC-123", 99.99, "2024-01-15 12:00:00", "EU"),
            (1002, 501, "DEF-456", 0.0, "2024-01-16 08:00:00", "US"),  # filtered: amount=0
            (None, 502, "GHI-789", 50.0, "2024-01-17 10:00:00", "APAC"),  # filtered: null id
        ]
        df = spark.createDataFrame(
            data, ["OrderID", "CustID", "ProdCode", "Total", "OrderDate", "Region"]
        )
        result = align_schema(df)

        assert result.count() == 1
        row = result.first()
        assert row.order_id == 1001
        assert row.customer_id == 500
        assert row.product_id == "ABC-123"
        assert row.amount == 99.99
        assert row.region == "EU"
