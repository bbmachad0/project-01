"""PySpark data quality checks - no external dependencies.

Each check is defined as a named assertion and evaluated lazily when
``run()`` is called.  The fluent API makes job scripts readable:

    checker = DataQualityChecker(df, "orders")
    checker.not_null("id").unique("id").min_value("amount", 0)
    checker.assert_all_passed()

All checks produce a ``CheckResult`` with name, status, and detail.
A ``DataQualityError`` is raised by ``assert_all_passed()`` when any
check fails, including a summary suitable for CloudWatch Logs.
"""

from __future__ import annotations

import logging
from collections.abc import Collection
from dataclasses import dataclass
from typing import Any

from pyspark.sql import DataFrame

logger = logging.getLogger(__name__)

# ─── Result types ─────────────────────────────────────────────────────────────


@dataclass
class CheckResult:
    """Result of a single data quality check."""

    name: str
    passed: bool
    column: str | None = None
    detail: str = ""

    def __str__(self) -> str:
        status = "PASS" if self.passed else "FAIL"
        col_info = f" [{self.column}]" if self.column else ""
        detail = f" - {self.detail}" if self.detail else ""
        return f"[{status}] {self.name}{col_info}{detail}"


class DataQualityError(Exception):
    """Raised when one or more data quality checks fail."""


# ─── Checker ──────────────────────────────────────────────────────────────────


class DataQualityChecker:
    """Fluent data quality checker for a PySpark DataFrame.

    Parameters
    ----------
    df:
        The DataFrame to validate.
    table_name:
        Logical name used in log messages and error reports.
    """

    def __init__(self, df: DataFrame, table_name: str = "unnamed") -> None:
        self._df = df
        self._table_name = table_name
        self._checks: list[tuple[str, Any]] = []

    # ─── Check definitions (fluent) ──────────────────────────────────────────

    def not_null(self, *columns: str) -> DataQualityChecker:
        """Assert that the given columns contain no NULL values."""
        for col in columns:
            self._checks.append(("not_null", col))
        return self

    def unique(self, *columns: str) -> DataQualityChecker:
        """Assert that values in each column are unique (no duplicates)."""
        for col in columns:
            self._checks.append(("unique", col))
        return self

    def value_in_set(self, column: str, allowed: Collection[Any]) -> DataQualityChecker:
        """Assert that all values in *column* are within the *allowed* set."""
        self._checks.append(("value_in_set", (column, set(allowed))))
        return self

    def min_value(self, column: str, minimum: float | int) -> DataQualityChecker:
        """Assert that all values in *column* are >= *minimum*."""
        self._checks.append(("min_value", (column, minimum)))
        return self

    def max_value(self, column: str, maximum: float | int) -> DataQualityChecker:
        """Assert that all values in *column* are <= *maximum*."""
        self._checks.append(("max_value", (column, maximum)))
        return self

    def row_count_min(self, minimum: int) -> DataQualityChecker:
        """Assert that the DataFrame has at least *minimum* rows."""
        self._checks.append(("row_count_min", minimum))
        return self

    # ─── Execution ───────────────────────────────────────────────────────────

    def run(self) -> dict[str, list[CheckResult]]:
        """Execute all registered checks and return a report dict.

        Returns
        -------
        dict with keys ``"passed"`` and ``"failed"``, each a list of
        :class:`CheckResult` objects.
        """
        from pyspark.sql import functions as F  # noqa: N812

        results: list[CheckResult] = []
        total_rows: int | None = None  # cached lazily

        def _count() -> int:
            nonlocal total_rows
            if total_rows is None:
                total_rows = self._df.count()
            return total_rows

        for check_type, params in self._checks:
            result: CheckResult

            if check_type == "not_null":
                col = params
                null_count = self._df.filter(F.col(col).isNull()).count()
                result = CheckResult(
                    name="not_null",
                    passed=null_count == 0,
                    column=col,
                    detail=f"{null_count} null(s) found" if null_count else "",
                )

            elif check_type == "unique":
                col = params
                total = _count()
                distinct = self._df.select(col).distinct().count()
                duplicates = total - distinct
                result = CheckResult(
                    name="unique",
                    passed=duplicates == 0,
                    column=col,
                    detail=f"{duplicates} duplicate(s) found" if duplicates else "",
                )

            elif check_type == "value_in_set":
                col, allowed = params
                invalid_count = self._df.filter(~F.col(col).isin(list(allowed))).count()
                result = CheckResult(
                    name="value_in_set",
                    passed=invalid_count == 0,
                    column=col,
                    detail=(
                        f"{invalid_count} row(s) outside allowed set {allowed}"
                        if invalid_count
                        else ""
                    ),
                )

            elif check_type == "min_value":
                col, minimum = params
                violating = self._df.filter(F.col(col) < minimum).count()
                result = CheckResult(
                    name="min_value",
                    passed=violating == 0,
                    column=col,
                    detail=f"{violating} row(s) below minimum {minimum}" if violating else "",
                )

            elif check_type == "max_value":
                col, maximum = params
                violating = self._df.filter(F.col(col) > maximum).count()
                result = CheckResult(
                    name="max_value",
                    passed=violating == 0,
                    column=col,
                    detail=f"{violating} row(s) above maximum {maximum}" if violating else "",
                )

            elif check_type == "row_count_min":
                minimum = params
                actual = _count()
                result = CheckResult(
                    name="row_count_min",
                    passed=actual >= minimum,
                    detail=f"got {actual}, expected >= {minimum}",
                )

            else:
                continue  # unknown check type - skip silently

            results.append(result)
            logger.info("[dq] %s - %s", self._table_name, result)

        passed = [r for r in results if r.passed]
        failed = [r for r in results if not r.passed]
        return {"passed": passed, "failed": failed}

    def assert_all_passed(self) -> None:
        """Run all checks and raise :class:`DataQualityError` if any fail.

        Raises
        ------
        DataQualityError
            If one or more checks fail.  The exception message includes a
            summary of all failures suitable for CloudWatch Logs.
        """
        report = self.run()
        failed = report["failed"]
        if failed:
            lines = "\n".join(f"  {r}" for r in failed)
            raise DataQualityError(
                f"Data quality failed for '{self._table_name}' ({len(failed)} check(s)):\n{lines}"
            )
