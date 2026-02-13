"""Runtime configuration resolver.

Loads configuration values from (in order of precedence):
1. Explicit keyword arguments
2. Environment variables (``DOMAIN_PROJECT_<KEY>``)
3. A YAML / JSON config file pointed to by ``CONFIG_PATH``
4. Hard-coded defaults

This keeps every job free of environment-specific literals.

Usage::

    from domain_project.core.config import get_config
    cfg = get_config()
    raw_bucket = cfg["s3_raw_bucket"]
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any, Dict, Optional


_ENV_PREFIX = "DOMAIN_PROJECT_"

_DEFAULTS: Dict[str, str] = {
    "env": "local",
    "s3_raw_bucket": "domain-project-raw",
    "s3_curated_bucket": "domain-project-curated",
    "s3_artifacts_bucket": "domain-project-artifacts",
    "iceberg_warehouse": "s3://domain-project-warehouse/iceberg/",
    "iceberg_database_raw": "raw",
    "iceberg_database_curated": "curated",
    "glue_catalog_id": "",
    "log_level": "INFO",
}


def _load_config_file(path: Optional[str] = None) -> Dict[str, Any]:
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
    config_path: Optional[str] = None,
    **overrides: Any,
) -> Dict[str, Any]:
    """Return a merged configuration dictionary.

    Parameters
    ----------
    config_path:
        Path to an optional JSON/YAML config file.
    **overrides:
        Explicit overrides that take highest precedence.
    """
    cfg: Dict[str, Any] = dict(_DEFAULTS)

    # Layer 1 — config file
    cfg.update(_load_config_file(config_path))

    # Layer 2 — environment variables
    for key in list(_DEFAULTS):
        env_val = os.getenv(f"{_ENV_PREFIX}{key.upper()}")
        if env_val is not None:
            cfg[key] = env_val

    # The generic ENV variable is a common shorthand
    env_override = os.getenv("ENV")
    if env_override:
        cfg["env"] = env_override.lower()

    # Layer 3 — explicit overrides
    cfg.update(overrides)

    return cfg
