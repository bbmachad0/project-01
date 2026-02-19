"""Runtime configuration resolver.

Loads configuration values from (in order of precedence):
1. Explicit keyword arguments
2. Environment variables (``{ABBR}_<KEY>``, derived from domain.json)
3. A YAML / JSON config file pointed to by ``CONFIG_PATH``
4. Defaults derived from ``domain.json``

This keeps every job free of environment-specific literals.

Usage::

    from core.config.settings import get_config
    cfg = get_config()
    raw_bucket = cfg["s3_raw_bucket"]
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any


def _load_domain() -> dict[str, str]:
    """Read domain.json from the repository root (best-effort)."""
    candidates = [
        Path(__file__).resolve().parents[3] / "domain.json",  # src/core/config -> repo root
        Path.cwd() / "domain.json",
    ]
    for p in candidates:
        if p.is_file():
            with p.open() as f:
                return json.load(f)
    return {}


_DOMAIN = _load_domain()
_ABBR = _DOMAIN.get("domain_abbr", "xx")
_ENV_PREFIX = f"{_ABBR.upper().replace('-', '_')}_"

_DEFAULTS: dict[str, str] = {
    "env": "local",
    "s3_raw_bucket": f"{_ABBR}-raw",
    "s3_curated_bucket": f"{_ABBR}-curated",
    "s3_artifacts_bucket": f"{_ABBR}-artifacts",
    "iceberg_warehouse": f"s3://{_ABBR}-warehouse/iceberg/",
    "iceberg_database_raw": f"{_ABBR.replace('-', '_')}_raw",
    "iceberg_database_refined": f"{_ABBR.replace('-', '_')}_refined",
    "iceberg_database_curated": f"{_ABBR.replace('-', '_')}_curated",
    "glue_catalog_id": "",
    "log_level": "INFO",
}


def _load_config_file(path: str | None = None) -> dict[str, Any]:
    """Load an optional JSON or YAML config file."""
    config_path = path or os.getenv("CONFIG_PATH")
    if not config_path:
        return {}

    p = Path(config_path)
    if not p.exists():
        return {}

    text = p.read_text()

    if p.suffix in (".yaml", ".yml"):
        try:
            import yaml  # optional dependency

            return yaml.safe_load(text) or {}
        except ImportError:
            return {}

    return json.loads(text)


def get_config(
    config_path: str | None = None,
    **overrides: Any,
) -> dict[str, Any]:
    """Return a merged configuration dictionary.

    Parameters
    ----------
    config_path:
        Path to an optional JSON/YAML config file.
    **overrides:
        Explicit overrides that take highest precedence.
    """
    cfg: dict[str, Any] = dict(_DEFAULTS)

    # Layer 1 - config file
    cfg.update(_load_config_file(config_path))

    # Layer 2 - environment variables
    for key in list(_DEFAULTS):
        env_val = os.getenv(f"{_ENV_PREFIX}{key.upper()}")
        if env_val is not None:
            cfg[key] = env_val

    # The generic ENV variable is a common shorthand
    env_override = os.getenv("ENV")
    if env_override:
        cfg["env"] = env_override.lower()

    # Layer 3 - explicit overrides
    cfg.update(overrides)

    return cfg
