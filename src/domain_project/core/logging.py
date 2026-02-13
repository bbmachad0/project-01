"""Structured logging helpers for Spark jobs.

Provides a thin wrapper around Python's standard ``logging`` module so
that every job emits structured, consistent log lines.  In AWS Glue
the output is forwarded to CloudWatch Logs automatically; locally it
writes to *stderr* for quick debugging.

Usage::

    from domain_project.core.logging import get_logger
    logger = get_logger(__name__)
    logger.info("Processing started", extra={"table": "orders"})
"""

from __future__ import annotations

import logging
import os
import sys
from typing import Optional


_DEFAULT_FORMAT = (
    "%(asctime)s | %(levelname)-8s | %(name)s | %(message)s"
)
_JSON_FORMAT = (
    '{"ts":"%(asctime)s","level":"%(levelname)s",'
    '"logger":"%(name)s","msg":"%(message)s"}'
)


def get_logger(
    name: str,
    level: Optional[int] = None,
    json_output: bool = False,
) -> logging.Logger:
    """Return a configured :class:`logging.Logger`.

    Parameters
    ----------
    name:
        Logger name — typically ``__name__`` of the calling module.
    level:
        Explicit level override.  When *None* the level is derived
        from the ``LOG_LEVEL`` environment variable (default ``INFO``).
    json_output:
        Emit structured JSON lines instead of plain text.
    """
    logger = logging.getLogger(name)

    if logger.handlers:
        # Already configured — avoid duplicate handlers on re-import.
        return logger

    resolved_level = level or getattr(
        logging, os.getenv("LOG_LEVEL", "INFO").upper(), logging.INFO
    )
    logger.setLevel(resolved_level)

    handler = logging.StreamHandler(sys.stderr)
    handler.setLevel(resolved_level)

    fmt = _JSON_FORMAT if json_output else _DEFAULT_FORMAT
    handler.setFormatter(logging.Formatter(fmt))
    logger.addHandler(handler)

    # Prevent log propagation to the root logger which Glue may reconfigure.
    logger.propagate = False

    return logger
