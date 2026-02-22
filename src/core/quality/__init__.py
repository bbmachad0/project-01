"""Data quality checks for PySpark DataFrames.

Provides a fluent API for defining and running assertions against
Iceberg or any other PySpark table, with no external dependencies.

Usage::

    from core.quality.checks import DataQualityChecker

    checker = (
        DataQualityChecker(df, "glue_catalog.f01_curated.orders")
        .not_null("id", "created_at")
        .value_in_set("status", {"active", "inactive", "pending"})
        .min_value("amount", 0)
        .max_value("amount", 1_000_000)
        .unique("id")
    )

    report = checker.run()          # {'passed': [...], 'failed': [...]}
    checker.assert_all_passed()     # raises DataQualityError on failure
"""

from core.quality.checks import DataQualityChecker, DataQualityError

__all__ = ["DataQualityChecker", "DataQualityError"]
